<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

class EnsurePermission
{
    public function handle(
        Request $request,
        Closure $next,
        string $permission
    ): Response {
        $user = $request->user();

        if (!$user) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $isAdmin = DB::table('role_user')
            ->join('roles', 'roles.id', '=', 'role_user.role_id')
            ->where('role_user.user_id', $user->id)
            ->where('roles.slug', 'admin')
            ->exists();

        if ($isAdmin) {
            $token = $user->currentAccessToken();

            if (!$token || !$token->can('admin:manage')) {
                return response()->json([
                    'message' => 'Enter the administrator activation code to manage data.',
                ], 403);
            }
        }

        $rolePermission = DB::table('permission_role')
            ->join('role_user', 'role_user.role_id', '=', 'permission_role.role_id')
            ->join('permissions', 'permissions.id', '=', 'permission_role.permission_id')
            ->where('role_user.user_id', $user->id)
            ->where('permissions.slug', $permission)
            ->exists();

        $directPermission = DB::table('user_permissions')
            ->join('permissions', 'permissions.id', '=', 'user_permissions.permission_id')
            ->where('user_permissions.user_id', $user->id)
            ->where('permissions.slug', $permission)
            ->exists();

        if (!$rolePermission && !$directPermission) {
            return response()->json([
                'message' => 'You do not have the required permission.',
                'required_permission' => $permission,
            ], 403);
        }

        return $next($request);
    }
}