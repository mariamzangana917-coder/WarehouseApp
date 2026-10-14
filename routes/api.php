<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PublicAccessController;
use App\Http\Controllers\Api\SectionController;
use App\Http\Controllers\Api\SectionContentController;
use App\Http\Controllers\Api\TableColumnController;
use App\Http\Controllers\Api\TableRowController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Anyone may browse without creating an account.
Route::post('/users/username', [PublicAccessController::class, 'registerUsername'])
    ->middleware('throttle:5,1');

Route::get('/auth/admin-identifier', [PublicAccessController::class, 'adminIdentifier']);

Route::post('/auth/admin-activate', [PublicAccessController::class, 'activateAdmin'])
    ->middleware('throttle:3,1');

Route::get('/sections', [SectionController::class, 'index']);
Route::get('/sections/{id}', [SectionController::class, 'show']);

Route::get('/sections/{sectionId}/contents', [SectionContentController::class, 'index']);
Route::get('/contents/{contentId}', [SectionContentController::class, 'show']);
Route::get('/contents/{contentId}/items', [SectionContentController::class, 'items']);
Route::get('/contents/{contentId}/columns', [SectionContentController::class, 'columns']);
Route::get('/contents/{contentId}/rows', [SectionContentController::class, 'rows']);

// Legacy table reads are also public.
Route::get('/sections/{sectionId}/columns', [TableColumnController::class, 'index']);
Route::get('/sections/{sectionId}/rows', [TableRowController::class, 'index']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/admin/users', [PublicAccessController::class, 'users'])
        ->middleware('permission:manage_users');

    Route::post('/sections', [SectionController::class, 'store'])
        ->middleware(['permission:create_sections', 'audit']);
    Route::put('/sections/{id}', [SectionController::class, 'update'])
        ->middleware(['permission:update_sections', 'audit']);
    Route::patch('/sections/{id}', [SectionController::class, 'update'])
        ->middleware(['permission:update_sections', 'audit']);
    Route::delete('/sections/{id}', [SectionController::class, 'destroy'])
        ->middleware(['permission:delete_sections', 'audit']);

    Route::post('/sections/{sectionId}/contents', [SectionContentController::class, 'store'])
        ->middleware(['permission:create_sections', 'audit']);
    Route::put('/contents/{contentId}', [SectionContentController::class, 'update'])
        ->middleware(['permission:update_sections', 'audit']);
    Route::patch('/contents/{contentId}', [SectionContentController::class, 'update'])
        ->middleware(['permission:update_sections', 'audit']);
    Route::delete('/contents/{contentId}', [SectionContentController::class, 'destroy'])
        ->middleware(['permission:delete_sections', 'audit']);

    Route::post('/contents/{contentId}/items', [SectionContentController::class, 'storeItem'])
        ->middleware(['permission:create_table_rows', 'audit']);
    Route::put('/items/{itemId}', [SectionContentController::class, 'updateItem'])
        ->middleware(['permission:update_table_rows', 'audit']);
    Route::patch('/items/{itemId}', [SectionContentController::class, 'updateItem'])
        ->middleware(['permission:update_table_rows', 'audit']);
    Route::delete('/items/{itemId}', [SectionContentController::class, 'destroyItem'])
        ->middleware(['permission:delete_table_rows', 'audit']);

    Route::post('/contents/{contentId}/columns', [SectionContentController::class, 'storeColumn'])
        ->middleware(['permission:create_table_columns', 'audit']);
    Route::put('/contents/{contentId}/columns/{columnId}', [SectionContentController::class, 'updateColumn'])
        ->middleware(['permission:update_table_columns', 'audit']);
    Route::patch('/contents/{contentId}/columns/{columnId}', [SectionContentController::class, 'updateColumn'])
        ->middleware(['permission:update_table_columns', 'audit']);
    Route::delete('/contents/{contentId}/columns/{columnId}', [SectionContentController::class, 'destroyColumn'])
        ->middleware(['permission:delete_table_columns', 'audit']);

    Route::post('/contents/{contentId}/rows', [SectionContentController::class, 'storeRow'])
        ->middleware(['permission:create_table_rows', 'audit']);
    Route::put('/contents/{contentId}/rows/{rowId}', [SectionContentController::class, 'updateRow'])
        ->middleware(['permission:update_table_rows', 'audit']);
    Route::patch('/contents/{contentId}/rows/{rowId}', [SectionContentController::class, 'updateRow'])
        ->middleware(['permission:update_table_rows', 'audit']);
    Route::delete('/contents/{contentId}/rows/{rowId}', [SectionContentController::class, 'destroyRow'])
        ->middleware(['permission:delete_table_rows', 'audit']);

    // Keep old table routes authenticated for compatibility.
    Route::post('/sections/{sectionId}/columns', [TableColumnController::class, 'store'])
        ->middleware(['permission:create_table_columns', 'audit']);
    Route::put('/columns/{id}', [TableColumnController::class, 'update'])
        ->middleware(['permission:update_table_columns', 'audit']);
    Route::patch('/columns/{id}', [TableColumnController::class, 'update'])
        ->middleware(['permission:update_table_columns', 'audit']);
    Route::delete('/columns/{id}', [TableColumnController::class, 'destroy'])
        ->middleware(['permission:delete_table_columns', 'audit']);

    Route::post('/sections/{sectionId}/rows', [TableRowController::class, 'store'])
        ->middleware(['permission:create_table_rows', 'audit']);
    Route::put('/rows/{id}', [TableRowController::class, 'update'])
        ->middleware(['permission:update_table_rows', 'audit']);
    Route::patch('/rows/{id}', [TableRowController::class, 'update'])
        ->middleware(['permission:update_table_rows', 'audit']);
    Route::patch('/rows/{id}/values', [TableRowController::class, 'updateValues'])
        ->middleware(['permission:edit_cell_values', 'audit']);
    Route::delete('/rows/{id}', [TableRowController::class, 'destroy'])
        ->middleware(['permission:delete_table_rows', 'audit']);

    Route::get('/user', function (Request $request) {
        return $request->user();
    });
});