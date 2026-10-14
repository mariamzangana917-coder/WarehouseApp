<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('table_rows', function (Blueprint $table) {
            $table->id();

            $table->foreignId('table_definition_id')
                ->constrained('table_definitions')
                ->cascadeOnDelete();

            $table->unsignedInteger('sort_order')->default(0);

            $table->foreignId('created_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestamps();

            $table->unique(['id', 'table_definition_id']);
            $table->index(['table_definition_id', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('table_rows');
    }
};