<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('table_cells', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('row_id');
            $table->unsignedBigInteger('column_id');
            $table->unsignedBigInteger('table_definition_id');
            $table->text('value')->nullable();
            $table->timestamps();

            $table->foreign(
                ['row_id', 'table_definition_id'],
                'cells_row_definition_fk'
            )->references(
                ['id', 'table_definition_id']
            )->on('table_rows')->cascadeOnDelete();

            $table->foreign(
                ['column_id', 'table_definition_id'],
                'cells_column_definition_fk'
            )->references(
                ['id', 'table_definition_id']
            )->on('table_columns')->cascadeOnDelete();

            $table->unique(['row_id', 'column_id']);
            $table->index('table_definition_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('table_cells');
    }
};