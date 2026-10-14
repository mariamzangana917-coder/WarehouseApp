<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class TableRowController extends Controller
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
            ->get();

        $rows = DB::table('table_rows')
            ->where('table_definition_id', $definition->id)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();

        $data = [];

        foreach ($rows as $row) {
            $data[] = $this->rowPayload($row);
        }

        return response()->json([
            'columns' => $columns,
            'data' => $data,
        ]);
    }

    public function store(Request $request, int $sectionId): JsonResponse
    {
        $definition = DB::table('table_definitions')
            ->where('section_id', $sectionId)
            ->first();

        if (!$definition) {
            return response()->json(['message' => 'Section not found.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'values' => ['required', 'array'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $columns = DB::table('table_columns')
            ->where('table_definition_id', $definition->id)
            ->orderBy('sort_order')
            ->get();

        if ($columns->isEmpty()) {
            return response()->json([
                'message' => 'Add table columns before adding rows.',
            ], 409);
        }

        $prepared = $this->prepareValues(
            $request->input('values'),
            $columns,
            true
        );

        if ($prepared['errors'] !== []) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $prepared['errors'],
            ], 422);
        }

        $columnMap = $columns->keyBy('column_key');
        $now = now();

        $rowId = DB::transaction(function () use (
            $request,
            $definition,
            $prepared,
            $columnMap,
            $now
        ) {
            $id = DB::table('table_rows')->insertGetId([
                'table_definition_id' => $definition->id,
                'sort_order' => $request->input('sort_order', 0),
                'created_by' => $request->user()->id,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            foreach ($prepared['values'] as $key => $value) {
                $column = $columnMap->get($key);

                DB::table('table_cells')->insert([
                    'row_id' => $id,
                    'column_id' => $column->id,
                    'table_definition_id' => $definition->id,
                    'value' => $value,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            return $id;
        });

        return response()->json([
            'message' => 'Row created successfully.',
            'data' => $this->rowPayload(
                DB::table('table_rows')->where('id', $rowId)->first()
            ),
        ], 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $row = DB::table('table_rows')->where('id', $id)->first();

        if (!$row) {
            return response()->json(['message' => 'Row not found.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'sort_order' => ['sometimes', 'required', 'integer', 'min:0'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        if ($data === []) {
            return response()->json([
                'message' => 'No changes provided.',
            ], 422);
        }

        $data['updated_at'] = now();

        DB::table('table_rows')->where('id', $id)->update($data);

        return response()->json([
            'message' => 'Row updated successfully.',
            'data' => $this->rowPayload(
                DB::table('table_rows')->where('id', $id)->first()
            ),
        ]);
    }

    public function updateValues(Request $request, int $id): JsonResponse
    {
        $row = DB::table('table_rows')->where('id', $id)->first();

        if (!$row) {
            return response()->json(['message' => 'Row not found.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'values' => ['required', 'array', 'min:1'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $columns = DB::table('table_columns')
            ->where('table_definition_id', $row->table_definition_id)
            ->get();

        $prepared = $this->prepareValues(
            $request->input('values'),
            $columns,
            false
        );

        if ($prepared['errors'] !== []) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $prepared['errors'],
            ], 422);
        }

        $columnMap = $columns->keyBy('column_key');
        $now = now();

        DB::transaction(function () use (
            $row,
            $prepared,
            $columnMap,
            $now
        ) {
            foreach ($prepared['values'] as $key => $value) {
                $column = $columnMap->get($key);

                $existing = DB::table('table_cells')
                    ->where('row_id', $row->id)
                    ->where('column_id', $column->id)
                    ->first();

                if ($existing) {
                    DB::table('table_cells')
                        ->where('id', $existing->id)
                        ->update([
                            'value' => $value,
                            'updated_at' => $now,
                        ]);
                } else {
                    DB::table('table_cells')->insert([
                        'row_id' => $row->id,
                        'column_id' => $column->id,
                        'table_definition_id' => $row->table_definition_id,
                        'value' => $value,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                }
            }
        });

        return response()->json([
            'message' => 'Cell values updated successfully.',
            'data' => $this->rowPayload(
                DB::table('table_rows')->where('id', $id)->first()
            ),
        ]);
    }

    public function destroy(int $id): JsonResponse
    {
        if (!DB::table('table_rows')->where('id', $id)->exists()) {
            return response()->json(['message' => 'Row not found.'], 404);
        }

        DB::table('table_rows')->where('id', $id)->delete();

        return response()->json([
            'message' => 'Row deleted successfully.',
        ]);
    }

    private function prepareValues(
        array $values,
        $columns,
        bool $requireAll
    ): array {
        $prepared = [];
        $errors = [];
        $columnMap = $columns->keyBy('column_key');

        foreach ($values as $key => $value) {
            if (!$columnMap->has((string) $key)) {
                $errors["values.$key"][] = 'Unknown column key.';
            }
        }

        foreach ($columns as $column) {
            $key = $column->column_key;
            $present = array_key_exists($key, $values);
            $value = $present ? $values[$key] : null;
            $empty = $value === null
                || (is_string($value) && trim($value) === '');

            if (!$present) {
                if ($requireAll && $column->is_required) {
                    $errors["values.$key"][] = 'This field is required.';
                }

                continue;
            }

            if ($empty) {
                if ($column->is_required) {
                    $errors["values.$key"][] = 'This field is required.';
                } else {
                    $prepared[$key] = null;
                }

                continue;
            }

            switch ($column->data_type) {
                case 'number':
                    if (
                        !is_numeric($value)
                        || (float) $value !== (float) (int) $value
                    ) {
                        $errors["values.$key"][] = 'An integer is required.';
                        continue 2;
                    }

                    $prepared[$key] = (string) $value;
                    break;

                case 'decimal':
                    if (!is_numeric($value)) {
                        $errors["values.$key"][] = 'A numeric value is required.';
                        continue 2;
                    }

                    $prepared[$key] = (string) $value;
                    break;

                case 'date':
                    if (!is_string($value) || strtotime($value) === false) {
                        $errors["values.$key"][] = 'A valid date is required.';
                        continue 2;
                    }

                    $prepared[$key] = trim($value);
                    break;

                case 'boolean':
                    if (is_bool($value)) {
                        $prepared[$key] = $value ? 'true' : 'false';
                    } elseif (in_array(
                        strtolower((string) $value),
                        ['0', '1', 'true', 'false'],
                        true
                    )) {
                        $prepared[$key] = in_array(
                            strtolower((string) $value),
                            ['1', 'true'],
                            true
                        ) ? 'true' : 'false';
                    } else {
                        $errors["values.$key"][] = 'A boolean value is required.';
                        continue 2;
                    }
                    break;

                default:
                    if (!is_string($value) && !is_numeric($value)) {
                        $errors["values.$key"][] = 'A text value is required.';
                        continue 2;
                    }

                    $prepared[$key] = trim((string) $value);
                    break;
            }
        }

        return [
            'values' => $prepared,
            'errors' => $errors,
        ];
    }

    private function rowPayload(object $row): array
    {
        $columns = DB::table('table_columns')
            ->where('table_definition_id', $row->table_definition_id)
            ->orderBy('sort_order')
            ->get(['column_key']);

        $values = [];

        foreach ($columns as $column) {
            $values[$column->column_key] = null;
        }

        $cells = DB::table('table_cells')
            ->join(
                'table_columns',
                'table_columns.id',
                '=',
                'table_cells.column_id'
            )
            ->where('table_cells.row_id', $row->id)
            ->select('table_columns.column_key', 'table_cells.value')
            ->get();

        foreach ($cells as $cell) {
            $values[$cell->column_key] = $cell->value;
        }

        return [
            'id' => (int) $row->id,
            'table_definition_id' => (int) $row->table_definition_id,
            'sort_order' => (int) $row->sort_order,
            'created_by' => $row->created_by === null
                ? null
                : (int) $row->created_by,
            'values' => (object) $values,
            'created_at' => $row->created_at,
            'updated_at' => $row->updated_at,
        ];
    }
}