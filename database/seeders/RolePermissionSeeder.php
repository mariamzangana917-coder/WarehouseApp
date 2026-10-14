<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class RolePermissionSeeder extends Seeder
{
    private const PERMISSIONS = [
        'manage_users',
        'create_sections', 'update_sections', 'delete_sections',
        'create_table_columns', 'update_table_columns', 'delete_table_columns',
        'create_table_rows', 'update_table_rows', 'delete_table_rows',
        'edit_cell_values',
    ];

    public function run(): void
    {
        $adminRoleId = $this->upsert('roles', 'admin', 'Administrator');
        $this->upsert('roles', 'user', 'User');

        foreach (self::PERMISSIONS as $slug) {
            $permissionId = $this->upsert('permissions', $slug, $slug);
            $pivot = ['permission_id' => $permissionId, 'role_id' => $adminRoleId];

            if (!DB::table('permission_role')->where($pivot)->exists()) {
                if (Schema::hasColumn('permission_role', 'created_at')) {
                    $pivot['created_at'] = now();
                    $pivot['updated_at'] = now();
                }
                DB::table('permission_role')->insert($pivot);
            }
        }
    }

    private function upsert(string $table, string $slug, string $name): int
    {
        $id = DB::table($table)->where('slug', $slug)->value('id');
        if ($id) {
            return (int) $id;
        }

        $row = ['slug' => $slug];
        if (Schema::hasColumn($table, 'name')) {
            $row['name'] = $name;
        }
        if (Schema::hasColumn($table, 'created_at')) {
            $row['created_at'] = now();
            $row['updated_at'] = now();
        }

        return (int) DB::table($table)->insertGetId($row);
    }
}
