<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_activation_codes', function (Blueprint $table): void {
            $table->id();
            $table->char('code_hash', 64)->unique();
            $table->string('intended_email', 255);

            $table->foreignId('created_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->foreignId('claimed_by')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestampTz('expires_at')->nullable();
            $table->timestampTz('used_at')->nullable();
            $table->timestampTz('revoked_at')->nullable();

            $table->timestampsTz();

            $table->index('intended_email');
            $table->index(['claimed_by', 'used_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_activation_codes');
    }
};