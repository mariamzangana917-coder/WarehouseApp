<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class AuditApiActivity
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);
        $method = strtoupper($request->method());

        if (
            !$request->user()
            || !in_array($method, ['POST', 'PUT', 'PATCH', 'DELETE'], true)
            || $response->getStatusCode() < 200
            || $response->getStatusCode() >= 300
        ) {
            return $response;
        }

        $route = $request->route();

        if (!$route) {
            return $response;
        }

        $uri = $route->uri();

        if (str_contains($uri, 'items')) {
            $subjectType = 'section_content_item';
        } elseif (str_contains($uri, 'columns')) {
            $subjectType = 'table_column';
        } elseif (str_contains($uri, 'rows')) {
            $subjectType = 'table_row';
        } elseif (str_contains($uri, 'contents')) {
            $subjectType = 'section_content';
        } elseif (str_contains($uri, 'sections')) {
            $subjectType = 'section';
        } else {
            return $response;
        }

        if (str_contains($uri, '/values')) {
            $action = 'table_cells.updated';
        } else {
            $verb = match ($method) {
                'POST' => 'created',
                'PUT', 'PATCH' => 'updated',
                'DELETE' => 'deleted',
            };

            $action = $subjectType . '.' . $verb;
        }

        $payload = json_decode($response->getContent(), true);
        $payload = is_array($payload) ? $payload : [];
        $parameters = $route->parameters();

        $subjectId = $payload['data']['id']
            ?? $parameters['id']
            ?? $parameters['itemId']
            ?? $parameters['contentId']
            ?? $parameters['sectionId']
            ?? null;

        $metadata = [
            'route' => $uri,
            'method' => $method,
            'status' => $response->getStatusCode(),
            'parameters' => $parameters,
        ];

        try {
            DB::table('audit_logs')->insert([
                'actor_user_id' => $request->user()->id,
                'action' => $action,
                'subject_type' => $subjectType,
                'subject_id' => is_numeric($subjectId) ? (int) $subjectId : null,
                'metadata' => json_encode(
                    $metadata,
                    JSON_UNESCAPED_UNICODE
                    | JSON_INVALID_UTF8_SUBSTITUTE
                    | JSON_THROW_ON_ERROR
                ),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'created_at' => now(),
            ]);
        } catch (Throwable $exception) {
            report($exception);
        }

        return $response;
    }
}