<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('section_contents', function (Blueprint $table) {
            $table->id();

            $table->foreignId('section_id')
                ->constrained('sections')
                ->cascadeOnDelete();

            $table->string('name', 150);
            $table->string('content_type', 20);
            $table->unsignedInteger('sort_order')->default(0);

            $table->foreignId('created_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestamps();

            $table->index(['section_id', 'sort_order']);
            $table->index(['section_id', 'content_type']);
        });

        Schema::table('table_definitions', function (Blueprint $table) {
            $table->unsignedBigInteger('section_content_id')
                ->nullable()
                ->unique();

            $table->foreign('section_content_id')
                ->references('id')
                ->on('section_contents')
                ->cascadeOnDelete();

            $table->foreignId('section_id')->nullable()->change();
        });

        $definitions = DB::table('table_definitions')
            ->join(
                'sections',
                'sections.id',
                '=',
                'table_definitions.section_id'
            )
            ->select(
                'table_definitions.id as definition_id',
                'table_definitions.section_id',
                'table_definitions.created_by',
                'sections.name as section_name'
            )
            ->get();

        foreach ($definitions as $definition) {
            $now = now();

            $contentId = DB::table('section_contents')->insertGetId([
                'section_id' => $definition->section_id,
                'name' => 'جدول ' . $definition->section_name,
                'content_type' => 'table',
                'sort_order' => 1,
                'created_by' => $definition->created_by,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            DB::table('table_definitions')
                ->where('id', $definition->definition_id)
                ->update([
                    'section_content_id' => $contentId,
                ]);
        }
    }

    public function down(): void
    {
        $hasNewDefinitions = DB::table('table_definitions')
            ->whereNull('section_id')
            ->whereNotNull('section_content_id')
            ->exists();

        if ($hasNewDefinitions) {
            throw new RuntimeException(
                'Cannot roll back: new content definitions exist.'
            );
        }

        Schema::table('table_definitions', function (Blueprint $table) {
            $table->dropForeign(['section_content_id']);
            $table->dropUnique(
                'table_definitions_section_content_id_unique'
            );
            $table->dropColumn('section_content_id');

            $table->foreignId('section_id')->nullable(false)->change();
        });

        Schema::dropIfExists('section_contents');
    }
};