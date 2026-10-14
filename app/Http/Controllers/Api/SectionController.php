<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class SectionController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'data' => DB::table('sections')
                ->orderBy('parent_id')
                ->orderBy('sort_order')
                ->orderBy('id')
                ->get(),
        ]);
    }

    public function show(int $id): JsonResponse
    {
        $section = DB::table('sections')->where('id', $id)->first();

        if (!$section) {
            return response()->json(['message' => 'Section not found.'], 404);
        }

        return response()->json(['data' => $section]);
    }

    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:150'],
            'parent_id' => ['nullable', 'integer', 'exists:sections,id'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $data = $validator->validated();
        $parent = !empty($data['parent_id'])
            ? DB::table('sections')->where('id', $data['parent_id'])->first()
            : null;

        $now = now();

        $id = DB::table('sections')->insertGetId([
            'parent_id' => $parent?->id,
            'level' => $parent ? ((int) $parent->level + 1) : 1,
            'name' => trim($data['name']),
            'sort_order' => $data['sort_order'] ?? 0,
            'created_by' => $request->user()->id,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return response()->json([
            'message' => 'Section created successfully.',
            'data' => DB::table('sections')->where('id', $id)->first(),
        ], 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        if (!DB::table('sections')->where('id', $id)->exists()) {
            return response()->json(['message' => 'Section not found.'], 404);
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

        if (!$data) {
            return response()->json(['message' => 'No changes provided.'], 422);
        }

        if (isset($data['name'])) {
            $data['name'] = trim($data['name']);
        }

        $data['updated_at'] = now();
        DB::table('sections')->where('id', $id)->update($data);

        return response()->json([
            'message' => 'Section updated successfully.',
            'data' => DB::table('sections')->where('id', $id)->first(),
        ]);
    }

    public function destroy(int $id): JsonResponse
    {
        if (!DB::table('sections')->where('id', $id)->exists()) {
            return response()->json(['message' => 'Section not found.'], 404);
        }

        if (DB::table('sections')->where('parent_id', $id)->exists()) {
            return response()->json(['message' => 'Remove child sections first.'], 409);
        }

        if (DB::table('section_contents')->where('section_id', $id)->exists()) {
            return response()->json([
                'message' => 'Remove section contents explicitly first.',
            ], 409);
        }

        $definitionId = DB::table('table_definitions')
            ->where('section_id', $id)
            ->value('id');

        if ($definitionId && (
            DB::table('table_rows')->where('table_definition_id', $definitionId)->exists()
            || DB::table('table_columns')->where('table_definition_id', $definitionId)->exists()
        )) {
            return response()->json([
                'message' => 'Remove legacy table data explicitly first.',
            ], 409);
        }

        DB::table('sections')->where('id', $id)->delete();

        return response()->json(['message' => 'Section deleted successfully.']);
    }
}