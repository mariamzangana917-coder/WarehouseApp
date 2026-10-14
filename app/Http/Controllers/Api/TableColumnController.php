<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Support\Str;

class TableColumnController extends Controller
{
    public function index(int $sectionId): JsonResponse
    {
        $definition = DB::table('table_definitions')
            ->where('section_id', $sectionId)
            ->first();

        if (!$definition) {
            return response()->json(['message' => 'Section not found.'], 404);
        }

        $columns = DB::table('table_columns')
            ->where('table_definition_id', $definition->id)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn ($column) => $this->normalizeSettings($column));

        return response()->json(['data' => $columns]);
    }

    public function store(Request $request, int $sectionId): JsonResponse
    {
        $definition = DB::table('table_definitions')
            ->where('section_id', $sectionId)
            ->first();

        if (!$definition) {
            return response()->json(['message' => 'Section not found.'], 404);
        }

        $definitionId = (int) $definition->id;

        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:150'],
            'column_key' => [
                'nullable',
                'string',
                'max:100',
                'regex:/^[a-z][a-z0-9_]*$/',
                Rule::unique('table_columns', 'column_key')
                    ->where(fn ($query) => $query->where(
                        'table_definition_id',
                        $definitionId
                    )),
            ],
            'data_type' => [
                'sometimes',
                'required',
                Rule::in(['text', 'number', 'decimal', 'date', 'boolean', 'select']),
            ],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'is_required' => ['sometimes', 'boolean'],
            'settings' => ['nullable', 'array'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();
        $key = $data['column_key'] ?? $this->makeColumnKey(
            trim($data['name']),
            $definitionId
        );

        $now = now();

        $id = DB::table('table_columns')->insertGetId([
            'table_definition_id' => $definitionId,
            'name' => trim($data['name']),
            'column_key' => $key,
            'data_type' => $data['data_type'] ?? 'text',
            'sort_order' => $data['sort_order'] ?? 0,
            'is_required' => $data['is_required'] ?? false,
            'settings' => isset($data['settings'])
                ? json_encode($data['settings'], JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR)
                : null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $column = DB::table('table_columns')->where('id', $id)->first();

        return response()->json([
            'message' => 'Column created successfully.',
            'data' => $this->normalizeSettings($column),
        ], 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $column = DB::table('table_columns')->where('id', $id)->first();

        if (!$column) {
            return response()->json(['message' => 'Column not found.'], 404);
        }

        $definitionId = (int) $column->table_definition_id;

        $validator = Validator::make($request->all(), [
            'name' => ['sometimes', 'required', 'string', 'max:150'],
            'column_key' => [
                'sometimes',
                'required',
                'string',
                'max:100',
                'regex:/^[a-z][a-z0-9_]*$/',
                Rule::unique('table_columns', 'column_key')
                    ->where(fn ($query) => $query->where(
                        'table_definition_id',
                        $definitionId
                    ))
                    ->ignore($id),
            ],
            'data_type' => [
                'sometimes',
                'required',
                Rule::in(['text', 'number', 'decimal', 'date', 'boolean', 'select']),
            ],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'is_required' => ['sometimes', 'boolean'],
            'settings' => ['sometimes', 'nullable', 'array'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        if (!$data) {
            return response()->json(['message' => 'No changes provided.'], 422);
        }

        if (isset($data['name'])) {
            $data['name'] = trim($data['name']);
        }

        if (array_key_exists('settings', $data)) {
            $data['settings'] = $data['settings'] === null
                ? null
                : json_encode(
                    $data['settings'],
                    JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR
                );
        }

        $data['updated_at'] = now();

        DB::table('table_columns')->where('id', $id)->update($data);

        $updated = DB::table('table_columns')->where('id', $id)->first();

        return response()->json([
            'message' => 'Column updated successfully.',
            'data' => $this->normalizeSettings($updated),
        ]);
    }

    public function destroy(int $id): JsonResponse
    {
        $column = DB::table('table_columns')->where('id', $id)->first();

        if (!$column) {
            return response()->json(['message' => 'Column not found.'], 404);
        }

        DB::transaction(function () use ($id) {
            DB::table('table_columns')->where('id', $id)->delete();
        });

        return response()->json(['message' => 'Column deleted successfully.']);
    }

    private function makeColumnKey(string $name, int $definitionId): string
    {
        $base = Str::slug($name, '_');

        if ($base === '' || !preg_match('/^[a-z]/', $base)) {
            $base = $base === '' ? 'column' : 'column_' . $base;
        }

        $base = substr($base, 0, 90);
        $key = $base;
        $suffix = 2;

        while (
            DB::table('table_columns')
                ->where('table_definition_id', $definitionId)
                ->where('column_key', $key)
                ->exists()
        ) {
            $key = $base . '_' . $suffix++;
        }

        return $key;
    }

    private function normalizeSettings(object $column): object
    {
        if (is_string($column->settings)) {
            $decoded = json_decode($column->settings, true);

            if (json_last_error() === JSON_ERROR_NONE) {
                $column->settings = $decoded;
            }
        }

        return $column;
    }
}