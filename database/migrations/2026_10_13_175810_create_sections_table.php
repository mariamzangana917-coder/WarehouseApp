<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('sections', function (Blueprint $table) {
            $table->id();
            $table->foreignId('parent_id')
                ->nullable()
                ->constrained('sections')
                ->cascadeOnDelete();

            $table->unsignedSmallInteger('level');
            $table->string('name', 150);
            $table->string('image_path')->nullable();
            $table->unsignedInteger('sort_order')->default(0);

            $table->foreignId('created_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestamps();

            $table->index(['parent_id', 'sort_order']);
            $table->index('level');
                   });
    }

    public function down(): void
    {
        Schema::dropIfExists('sections');
    }
};