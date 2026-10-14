<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('username', 40)->nullable()->unique();
            $table->string('email')->nullable()->change();
        });

        $used = [];

        $users = DB::table('users')->select('id', 'email')->orderBy('id')->get();

        foreach ($users as $user) {
            $email = (string) ($user->email ?? '');
            $base = strtolower(explode('@', $email)[0] ?: 'user' . $user->id);
            $base = preg_replace('/[^a-z0-9_]+/', '_', $base);
            $base = trim($base, '_');

            if ($base === '' || !preg_match('/^[a-z]/', $base)) {
                $base = 'user_' . $base;
            }

            $base = substr($base, 0, 40);
            if (strlen($base) < 3) {
                $base = str_pad($base, 3, 'x');
            }

            $candidate = $base;
            $suffix = 1;

            while (isset($used[$candidate])) {
                $tail = '_' . $suffix++;
                $candidate = substr($base, 0, 40 - strlen($tail)) . $tail;
            }

            $used[$candidate] = true;

            DB::table('users')->where('id', $user->id)->update([
                'username' => $candidate,
            ]);
        }

        $adminId = DB::table('role_user')
            ->join('roles', 'roles.id', '=', 'role_user.role_id')
            ->where('roles.slug', 'admin')
            ->orderBy('role_user.user_id')
            ->value('role_user.user_id');

        if ($adminId) {
            $conflict = DB::table('users')
                ->where('username', 'warehouse_admin')
                ->where('id', '<>', $adminId)
                ->first();

            if ($conflict) {
                $replacement = 'member_' . $conflict->id;
                $suffix = 1;

                while (
                    DB::table('users')
                        ->where('username', $replacement)
                        ->where('id', '<>', $conflict->id)
                        ->exists()
                ) {
                    $replacement = 'member_' . $conflict->id . '_' . $suffix++;
                }

                DB::table('users')->where('id', $conflict->id)->update([
                    'username' => $replacement,
                ]);
            }

            DB::table('users')->where('id', $adminId)->update([
                'username' => 'warehouse_admin',
            ]);
        }
    }

    public function down(): void
    {
        if (DB::table('users')->whereNull('email')->exists()) {
            throw new RuntimeException(
                'Cannot roll back username migration while username-only accounts exist.'
            );
        }

        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['username']);
            $table->dropColumn('username');
            $table->string('email')->nullable(false)->change();
        });
    }
};