<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Database\QueryException;
use Throwable;

class PublicAccessController extends Controller
{
    public function adminIdentifier(): JsonResponse
    {
        return response()->json([
            'username' => strtolower(trim((string) config('warehouse_admin.username', 'warehouse_admin'))),
        ]);
    }

    public function registerUsername(Request $request): JsonResponse
    {
        $request->merge([
            'username' => strtolower(trim((string) preg_replace('/[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}\x{FEFF}]/u', '', (string) $request->input('username')))),
        ]);

        $validator = Validator::make($request->all(), [
            'username' => [
                'required',
                'string',
                'min:3',
                'max:40',
                'regex:/^[a-z][a-z0-9_]*$/',
            ],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Username must use English letters, numbers, or underscores and start with a letter.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $username = $request->input('username');

        $adminUsername = strtolower(trim((string) config('warehouse_admin.username', 'warehouse_admin')));

        if ($username === $adminUsername) {
            return response()->json([
                'message' => 'This username is reserved.',
            ], 409);
        }

        if (DB::table('users')->where('username', $username)->exists()) {
            return response()->json([
                'message' => 'Username is already taken. Choose another username.',
            ], 409);
        }

        try {
            $user = DB::transaction(function () use ($username) {
                $user = User::create([
                    'name' => $username,
                    'username' => $username,
                    'email' => null,
                    'password' => Str::random(64),
                ]);

                $roleId = DB::table('roles')->where('slug', 'user')->value('id');

                if ($roleId) {
                    DB::table('role_user')->insert([
                        'user_id' => $user->id,
                        'role_id' => (int) $roleId,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }

                return $user;
            });
        } catch (QueryException $exception) {
            return response()->json([
                'message' => 'Username is already taken. Choose another username.',
            ], 409);
        }

        $this->audit(null, 'user.username_registered', (int) $user->id, $request);

        return response()->json([
            'message' => 'Username registered successfully.',
            'user' => [
                'id' => $user->id,
                'username' => $user->username,
                'created_at' => $user->created_at,
            ],
        ], 201);
    }

    public function activateAdmin(Request $request): JsonResponse
    {
        $request->merge([
            'username' => strtolower(trim((string) preg_replace('/[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}\x{FEFF}]/u', '', (string) $request->input('username')))),
        ]);

        $validator = Validator::make($request->all(), [
            'username' => [
                'required', 'string', 'min:3', 'max:40',
                'regex:/^[a-z][a-z0-9_]*$/',
            ],
            'code' => ['required', 'string', 'max:256'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Invalid administrator credentials.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $adminUsername = strtolower(trim((string) config('warehouse_admin.username', 'warehouse_admin')));
        $expectedHash = (string) config('warehouse.admin_activation_code_hash', '');

        if (!preg_match('/^[a-f0-9]{64}$/i', $expectedHash)) {
            return response()->json([
                'message' => 'Administrator activation is not configured.',
            ], 503);
        }

        $usernameMatches = hash_equals($adminUsername, $request->input('username'));
        $submittedHash = hash('sha256', trim($request->input('code')));
        $codeMatches = hash_equals(strtolower($expectedHash), $submittedHash);

        if (!$usernameMatches || !$codeMatches) {
            $this->audit(
                null,
                'admin.activation.failed',
                null,
                $request,
                ['reason' => 'invalid_credentials']
            );

            return response()->json([
                'message' => 'Invalid administrator credentials.',
            ], 422);
        }

        $adminRoleId = DB::table('roles')->where('slug', 'admin')->value('id');

        if (!$adminRoleId) {
            return response()->json([
                'message' => 'Administrator role is not configured.',
            ], 503);
        }

        $userId = DB::transaction(function () use ($request, $adminUsername, $adminRoleId) {
            $user = User::where('username', $adminUsername)
                ->lockForUpdate()
                ->first();

            if (!$user) {
                $user = User::create([
                    'name' => $adminUsername,
                    'username' => $adminUsername,
                    'email' => null,
                    'password' => Str::random(64),
                ]);
            }

            $userId = (int) $user->id;

            $alreadyAdmin = DB::table('role_user')
                ->where('user_id', $userId)
                ->where('role_id', (int) $adminRoleId)
                ->exists();

            if (!$alreadyAdmin) {
                DB::table('role_user')->where('user_id', $userId)->delete();

                DB::table('role_user')->insert([
                    'user_id' => $userId,
                    'role_id' => (int) $adminRoleId,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            $this->audit(
                $userId,
                'admin.activation.succeeded',
                $userId,
                $request
            );

            return $userId;
        });

        $user = User::findOrFail($userId);
        $token = $user->createToken('warehouse-admin', ['admin:manage'])->plainTextToken;

        return response()->json([
            'message' => 'Administrator access activated successfully.',
            'user' => [
                'id' => $user->id,
                'username' => $user->username,
                'name' => $user->name,
            ],
            'token' => $token,
            'token_type' => 'Bearer',
        ]);
    }

    public function users(): JsonResponse
    {
        $paginator = DB::table('users')
            ->select('id', 'username', 'name', 'created_at')
            ->orderByDesc('id')
            ->paginate(50);

        $ids = $paginator->getCollection()->pluck('id')->all();
        $roleMap = [];

        if ($ids !== []) {
            $roleRows = DB::table('role_user')
                ->join('roles', 'roles.id', '=', 'role_user.role_id')
                ->whereIn('role_user.user_id', $ids)
                ->get(['role_user.user_id', 'roles.slug']);

            foreach ($roleRows as $role) {
                $roleMap[(int) $role->user_id][] = $role->slug;
            }
        }

        $paginator->getCollection()->transform(function ($user) use ($roleMap) {
            $user->roles = $roleMap[(int) $user->id] ?? ['user'];
            return $user;
        });

        return response()->json($paginator);
    }

    private function audit(
        ?int $actorId,
        string $action,
        ?int $subjectId,
        Request $request,
        array $metadata = []
    ): void {
        try {
            DB::table('audit_logs')->insert([
                'actor_user_id' => $actorId,
                'action' => $action,
                'subject_type' => 'user',
                'subject_id' => $subjectId,
                'metadata' => json_encode(
                    $metadata,
                    JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE
                ),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'created_at' => now(),
            ]);
        } catch (Throwable $exception) {
            report($exception);
        }
    }
}