<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('section_content_items', function (Blueprint $table) {
            $table->id();

            $table->foreignId('section_content_id')
                ->constrained('section_contents')
                ->cascadeOnDelete();

            $table->string('label', 150)->nullable();
            $table->jsonb('data');
            $table->unsignedInteger('sort_order')->default(0);

            $table->foreignId('created_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestamps();

            $table->index(['section_content_id', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('section_content_items');
    }
};