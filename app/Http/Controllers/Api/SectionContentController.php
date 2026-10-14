<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Support\Str;

class SectionContentController extends Controller
{
    public function index(int $sectionId): JsonResponse
    {
        if (!DB::table('sections')->where('id', $sectionId)->exists()) {
            return response()->json(['message' => 'Section not found.'], 404);
        }

        $contents = DB::table('section_contents')
            ->leftJoin(
                'table_definitions',
                'table_definitions.section_content_id',
                '=',
                'section_contents.id'
            )
            ->where('section_contents.section_id', $sectionId)
            ->select(
                'section_contents.*',
                'table_definitions.id as table_definition_id'
            )
            ->orderBy('section_contents.sort_order')
            ->orderBy('section_contents.id')
            ->get();

        return response()->json(['data' => $contents]);
    }

    public function store(Request $request, int $sectionId): JsonResponse
    {
        if (!DB::table('sections')->where('id', $sectionId)->exists()) {
            return response()->json(['message' => 'Section not found.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:150'],
            'content_type' => ['required', Rule::in(['list', 'table'])],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();
        $now = now();
        $userId = $request->user()->id;

        $contentId = DB::transaction(function () use (
            $sectionId,
            $data,
            $now,
            $userId
        ) {
            $id = DB::table('section_contents')->insertGetId([
                'section_id' => $sectionId,
                'name' => trim($data['name']),
                'content_type' => $data['content_type'],
                'sort_order' => $data['sort_order'] ?? 0,
                'created_by' => $userId,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            if ($data['content_type'] === 'table') {
                DB::table('table_definitions')->insert([
                    'section_id' => null,
                    'section_content_id' => $id,
                    'created_by' => $userId,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            return $id;
        });

        return response()->json([
            'message' => 'Content created successfully.',
            'data' => $this->contentPayload($contentId),
        ], 201);
    }

    public function show(int $contentId): JsonResponse
    {
        $content = $this->contentPayload($contentId);

        if (!$content) {
            return response()->json(['message' => 'Content not found.'], 404);
        }

        return response()->json(['data' => $content]);
    }

    public function update(Request $request, int $contentId): JsonResponse
    {
        if (!DB::table('section_contents')->where('id', $contentId)->exists()) {
            return response()->json(['message' => 'Content not found.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => ['sometimes', 'required', 'string', 'max:150'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        if ($data === []) {
            return response()->json(['message' => 'No changes provided.'], 422);
        }

        if (isset($data['name'])) {
            $data['name'] = trim($data['name']);
        }

        $data['updated_at'] = now();

        DB::table('section_contents')->where('id', $contentId)->update($data);

        return response()->json([
            'message' => 'Content updated successfully.',
            'data' => $this->contentPayload($contentId),
        ]);
    }

    public function destroy(int $contentId): JsonResponse
    {
        $content = DB::table('section_contents')
            ->where('id', $contentId)
            ->first();

        if (!$content) {
            return response()->json(['message' => 'Content not found.'], 404);
        }

        if ($content->content_type === 'list') {
            if (DB::table('section_content_items')
                ->where('section_content_id', $contentId)->exists()) {
                return response()->json([
                    'message' => 'Remove list items explicitly before deleting this content.',
                ], 409);
            }
        } else {
            $definitionId = DB::table('table_definitions')
                ->where('section_content_id', $contentId)
                ->value('id');

            if ($definitionId && (
                DB::table('table_rows')->where('table_definition_id', $definitionId)->exists()
                || DB::table('table_columns')->where('table_definition_id', $definitionId)->exists()
            )) {
                return response()->json([
                    'message' => 'Remove table rows and columns explicitly before deleting this content.',
                ], 409);
            }
        }

        DB::table('section_contents')->where('id', $contentId)->delete();

        return response()->json(['message' => 'Content deleted successfully.']);
    }

    public function items(int $contentId): JsonResponse
    {
        $content = DB::table('section_contents')->where('id', $contentId)->first();

        if (!$content) {
            return response()->json(['message' => 'Content not found.'], 404);
        }

        if ($content->content_type !== 'list') {
            return response()->json(['message' => 'This content is not a list.'], 409);
        }

        $items = DB::table('section_content_items')
            ->where('section_content_id', $contentId)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn ($item) => $this->itemPayload($item));

        return response()->json(['data' => $items]);
    }

    public function storeItem(Request $request, int $contentId): JsonResponse
    {
        $content = DB::table('section_contents')->where('id', $contentId)->first();

        if (!$content) {
            return response()->json(['message' => 'Content not found.'], 404);
        }

        if ($content->content_type !== 'list') {
            return response()->json(['message' => 'This content is not a list.'], 409);
        }

        $validator = Validator::make($request->all(), [
            'label' => ['nullable', 'string', 'max:150'],
            'data' => ['required', 'array'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();
        $now = now();

        $id = DB::table('section_content_items')->insertGetId([
            'section_content_id' => $contentId,
            'label' => isset($data['label']) ? trim($data['label']) : null,
            'data' => json_encode(
                $data['data'],
                JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR
            ),
            'sort_order' => $data['sort_order'] ?? 0,
            'created_by' => $request->user()->id,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $item = DB::table('section_content_items')->where('id', $id)->first();

        return response()->json([
            'message' => 'List item created successfully.',
            'data' => $this->itemPayload($item),
        ], 201);
    }

    public function updateItem(Request $request, int $itemId): JsonResponse
    {
        $item = DB::table('section_content_items')->where('id', $itemId)->first();

        if (!$item) {
            return response()->json(['message' => 'List item not found.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'label' => ['sometimes', 'nullable', 'string', 'max:150'],
            'data' => ['sometimes', 'required', 'array'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();

        if ($data === []) {
            return response()->json(['message' => 'No changes provided.'], 422);
        }

        if (array_key_exists('label', $data) && $data['label'] !== null) {
            $data['label'] = trim($data['label']);
        }

        if (array_key_exists('data', $data)) {
            $data['data'] = json_encode(
                $data['data'],
                JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR
            );
        }

        $data['updated_at'] = now();

        DB::table('section_content_items')->where('id', $itemId)->update($data);

        return response()->json([
            'message' => 'List item updated successfully.',
            'data' => $this->itemPayload(
                DB::table('section_content_items')->where('id', $itemId)->first()
            ),
        ]);
    }

    public function destroyItem(int $itemId): JsonResponse
    {
        if (!DB::table('section_content_items')->where('id', $itemId)->exists()) {
            return response()->json(['message' => 'List item not found.'], 404);
        }

        DB::table('section_content_items')->where('id', $itemId)->delete();

        return response()->json(['message' => 'List item deleted successfully.']);
    }

    public function columns(int $contentId): JsonResponse
    {
        $definition = $this->tableDefinition($contentId);

        if (!$definition) {
            return $this->tableContentError($contentId);
        }

        $columns = DB::table('table_columns')
            ->where('table_definition_id', $definition->id)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(function ($column) {
                if (is_string($column->settings)) {
                    $decoded = json_decode($column->settings, true);
                    if (json_last_error() === JSON_ERROR_NONE) {
                        $column->settings = $decoded;
                    }
                }
                return $column;
            });

        return response()->json(['data' => $columns]);
    }

    public function storeColumn(Request $request, int $contentId): JsonResponse
    {
        $definition = $this->tableDefinition($contentId);

        if (!$definition) {
            return $this->tableContentError($contentId);
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
        $key = $data['column_key'] ?? $this->generatedColumnKey($definitionId);
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

        return response()->json([
            'message' => 'Column created successfully.',
            'data' => DB::table('table_columns')->where('id', $id)->first(),
        ], 201);
    }

    public function rows(int $contentId): JsonResponse
    {
        $definition = $this->tableDefinition($contentId);

        if (!$definition) {
            return $this->tableContentError($contentId);
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
            ->get()
            ->map(fn ($row) => $this->rowPayload($row, $columns));

        return response()->json([
            'columns' => $columns,
            'data' => $rows,
        ]);
    }

    public function storeRow(Request $request, int $contentId): JsonResponse
    {
        $definition = $this->tableDefinition($contentId);

        if (!$definition) {
            return $this->tableContentError($contentId);
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
                'message' => 'Add columns before adding rows.',
            ], 409);
        }

        $prepared = $this->prepareValues($request->input('values'), $columns);

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
                DB::table('table_rows')->where('id', $rowId)->first(),
                $columns
            ),
        ], 201);
    }

    public function updateColumn(Request $request, int $contentId, int $columnId): JsonResponse
    {
        $definition = $this->tableDefinition($contentId);

        if (!$definition) {
            return $this->tableContentError($contentId);
        }

        $column = DB::table('table_columns')
            ->where('id', $columnId)
            ->where('table_definition_id', $definition->id)
            ->first();

        if (!$column) {
            return response()->json(['message' => 'Column not found.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => ['sometimes', 'required', 'string', 'max:150'],
            'column_key' => [
                'sometimes', 'required', 'string', 'max:100',
                'regex:/^[a-z][a-z0-9_]*$/',
                Rule::unique('table_columns', 'column_key')
                    ->where(fn ($query) => $query->where(
                        'table_definition_id', $definition->id
                    ))
                    ->ignore($columnId),
            ],
            'data_type' => [
                'sometimes', 'required',
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

        if (
            isset($data['data_type'])
            && $data['data_type'] !== $column->data_type
            && DB::table('table_cells')
                ->where('column_id', $columnId)
                ->whereNotNull('value')
                ->exists()
        ) {
            return response()->json([
                'message' => 'Clear this column values before changing its data type.',
            ], 409);
        }

        if (isset($data['name'])) {
            $data['name'] = trim($data['name']);
        }

        if (array_key_exists('settings', $data)) {
            $data['settings'] = $data['settings'] === null
                ? null
                : json_encode($data['settings'], JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
        }

        $data['updated_at'] = now();

        DB::table('table_columns')->where('id', $columnId)->update($data);

        return response()->json([
            'message' => 'Column updated successfully.',
            'data' => DB::table('table_columns')->where('id', $columnId)->first(),
        ]);
    }

    public function destroyColumn(int $contentId, int $columnId): JsonResponse
    {
        $definition = $this->tableDefinition($contentId);

        if (!$definition) {
            return $this->tableContentError($contentId);
        }

        $column = DB::table('table_columns')
            ->where('id', $columnId)
            ->where('table_definition_id', $definition->id)
            ->first();

        if (!$column) {
            return response()->json(['message' => 'Column not found.'], 404);
        }

        DB::table('table_columns')->where('id', $columnId)->delete();

        return response()->json([
            'message' => 'Column and its cell values deleted successfully.',
        ]);
    }

    public function updateRow(
        Request $request,
        int $contentId,
        int $rowId
    ): JsonResponse {
        $definition = $this->tableDefinition($contentId);

        if (!$definition) {
            return $this->tableContentError($contentId);
        }

        $row = DB::table('table_rows')
            ->where('id', $rowId)
            ->where('table_definition_id', $definition->id)
            ->first();

        if (!$row) {
            return response()->json(['message' => 'Row not found.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'values' => ['sometimes', 'required', 'array', 'min:1'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
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

        $columns = DB::table('table_columns')
            ->where('table_definition_id', $definition->id)
            ->orderBy('sort_order')
            ->get();

        DB::transaction(function () use (
            $data,
            $row,
            $columns,
            $definition
        ) {
            if (array_key_exists('sort_order', $data)) {
                DB::table('table_rows')->where('id', $row->id)->update([
                    'sort_order' => $data['sort_order'],
                    'updated_at' => now(),
                ]);
            }

            if (array_key_exists('values', $data)) {
                $previous = [];

                $cells = DB::table('table_cells')
                    ->join('table_columns', 'table_columns.id', '=', 'table_cells.column_id')
                    ->where('table_cells.row_id', $row->id)
                    ->get(['table_columns.column_key', 'table_cells.value']);

                foreach ($cells as $cell) {
                    $previous[$cell->column_key] = $cell->value;
                }

                $combined = array_merge($previous, $data['values']);
                $prepared = $this->prepareValues($combined, $columns);

                if ($prepared['errors'] !== []) {
                    throw \Illuminate\Validation\ValidationException::withMessages(
                        $prepared['errors']
                    );
                }

                $columnMap = $columns->keyBy('column_key');
                $now = now();

                foreach ($prepared['values'] as $key => $value) {
                    $column = $columnMap->get($key);

                    $cell = DB::table('table_cells')
                        ->where('row_id', $row->id)
                        ->where('column_id', $column->id)
                        ->first();

                    if ($cell) {
                        DB::table('table_cells')->where('id', $cell->id)->update([
                            'value' => $value,
                            'updated_at' => $now,
                        ]);
                    } else {
                        DB::table('table_cells')->insert([
                            'row_id' => $row->id,
                            'column_id' => $column->id,
                            'table_definition_id' => $definition->id,
                            'value' => $value,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ]);
                    }
                }
            }

            DB::table('table_rows')->where('id', $row->id)->update([
                'updated_at' => now(),
            ]);
        });

        return response()->json([
            'message' => 'Row updated successfully.',
        ]);
    }

    public function destroyRow(int $contentId, int $rowId): JsonResponse
    {
        $definition = $this->tableDefinition($contentId);

        if (!$definition) {
            return $this->tableContentError($contentId);
        }

        $deleted = DB::table('table_rows')
            ->where('id', $rowId)
            ->where('table_definition_id', $definition->id)
            ->delete();

        if (!$deleted) {
            return response()->json(['message' => 'Row not found.'], 404);
        }

        return response()->json(['message' => 'Row deleted successfully.']);
    }
    private function contentPayload(int $contentId): ?object
    {
        return DB::table('section_contents')
            ->leftJoin(
                'table_definitions',
                'table_definitions.section_content_id',
                '=',
                'section_contents.id'
            )
            ->where('section_contents.id', $contentId)
            ->select(
                'section_contents.*',
                'table_definitions.id as table_definition_id'
            )
            ->first();
    }

    private function itemPayload(object $item): array
    {
        $data = $item->data;

        if (is_string($data)) {
            $decoded = json_decode($data, true);

            if (json_last_error() === JSON_ERROR_NONE) {
                $data = $decoded;
            }
        }

        return [
            'id' => (int) $item->id,
            'section_content_id' => (int) $item->section_content_id,
            'label' => $item->label,
            'data' => $data,
            'sort_order' => (int) $item->sort_order,
            'created_by' => $item->created_by === null
                ? null : (int) $item->created_by,
            'created_at' => $item->created_at,
            'updated_at' => $item->updated_at,
        ];
    }

    private function tableDefinition(int $contentId): ?object
    {
        $content = DB::table('section_contents')->where('id', $contentId)->first();

        if (!$content || $content->content_type !== 'table') {
            return null;
        }

        return DB::table('table_definitions')
            ->where('section_content_id', $contentId)
            ->first();
    }

    private function tableContentError(int $contentId): JsonResponse
    {
        $content = DB::table('section_contents')->where('id', $contentId)->first();

        if (!$content) {
            return response()->json(['message' => 'Content not found.'], 404);
        }

        return response()->json([
            'message' => 'Choose a table content to use columns and rows.',
        ], 409);
    }

    private function generatedColumnKey(int $definitionId): string
    {
        do {
            $key = 'field_' . Str::lower(Str::random(8));
        } while (
            DB::table('table_columns')
                ->where('table_definition_id', $definitionId)
                ->where('column_key', $key)
                ->exists()
        );

        return $key;
    }

    private function prepareValues(array $values, $columns): array
    {
        $errors = [];
        $prepared = [];
        $columnMap = $columns->keyBy('column_key');

        foreach ($values as $key => $value) {
            if (!$columnMap->has((string) $key)) {
                $errors["values.$key"][] = 'Unknown column key.';
            }
        }

        foreach ($columns as $column) {
            $key = $column->column_key;
            $present = array_key_exists($key, $values);

            if (!$present) {
                if ($column->is_required) {
                    $errors["values.$key"][] = 'This field is required.';
                }
                continue;
            }

            $value = $values[$key];
            $empty = $value === null || (is_string($value) && trim($value) === '');

            if ($empty) {
                if ($column->is_required) {
                    $errors["values.$key"][] = 'This field is required.';
                } else {
                    $prepared[$key] = null;
                }
                continue;
            }

            if (!is_scalar($value)) {
                $errors["values.$key"][] = 'A single value is required.';
                continue;
            }

            if ($column->data_type === 'number') {
                if (!is_numeric($value) || (float) $value !== (float) (int) $value) {
                    $errors["values.$key"][] = 'An integer is required.';
                    continue;
                }
            } elseif ($column->data_type === 'decimal') {
                if (!is_numeric($value)) {
                    $errors["values.$key"][] = 'A numeric value is required.';
                    continue;
                }
            } elseif ($column->data_type === 'date') {
                if (strtotime((string) $value) === false) {
                    $errors["values.$key"][] = 'A valid date is required.';
                    continue;
                }
            } elseif ($column->data_type === 'boolean') {
                $booleanValue = strtolower((string) $value);

                if (!in_array($booleanValue, ['0', '1', 'true', 'false'], true)) {
                    $errors["values.$key"][] = 'A boolean value is required.';
                    continue;
                }

                $value = in_array($booleanValue, ['1', 'true'], true)
                    ? 'true' : 'false';
            }

            $prepared[$key] = trim((string) $value);
        }

        return ['values' => $prepared, 'errors' => $errors];
    }

    private function rowPayload(object $row, $columns): array
    {
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
                ? null : (int) $row->created_by,
            'values' => (object) $values,
            'created_at' => $row->created_at,
            'updated_at' => $row->updated_at,
        ];
    }
}