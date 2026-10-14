<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('table_columns', function (Blueprint $table) {
            $table->id();

            $table->foreignId('table_definition_id')
                ->constrained('table_definitions')
                ->cascadeOnDelete();

            $table->string('name', 150);
            $table->string('column_key', 100);
            $table->string('data_type', 30)->default('text');
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_required')->default(false);
            $table->jsonb('settings')->nullable();
            $table->timestamps();

            $table->unique(['table_definition_id', 'column_key']);
            $table->unique(['id', 'table_definition_id']);
            $table->index(['table_definition_id', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('table_columns');
    }
};