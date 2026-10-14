Flutter:  انسخي مجلد flutter/lib فوق lib الحالي (يستبدل main.dart ويضيف مجلد src).
          ما يحتاج تغيير pubspec.yaml (نفس الحزم: http فقط).
          عنوان الخادم: --dart-define=WAREHOUSE_API_URL=http://IP:8000/api
Laravel:  انسخي مجلد laravel فوق المشروع، بعدها:
          php artisan migrate
          php artisan db:seed
          php artisan config:clear
## WarehouseApp — Developer Handover

### Project structure
- Laravel API backend: project root
- Flutter application: `app_flutter`
- Database: PostgreSQL
- Database name: `warehouse_app`

### Requirements
- PHP version compatible with the Laravel project
- Composer
- PostgreSQL
- Flutter SDK
- Android Studio or another Flutter-compatible IDE

### Backend setup
1. Install PHP dependencies:
   `composer install`
2. Copy `.env.example` to `.env`.
3. Configure PostgreSQL credentials in `.env`. Never commit real passwords or secret keys.
4. Generate the Laravel application key:
   `php artisan key:generate`
5. Run the backend:
   `php artisan serve --host=0.0.0.0 --port=8000`

### Flutter setup
1. Open the `app_flutter` directory.
2. Run `flutter pub get`.
3. Configure `WAREHOUSE_API_URL` for the computer or server hosting the API.
4. Run the app using the appropriate Flutter device or target.

### Database
The project uses PostgreSQL. The database backup is distributed separately and must be restored into PostgreSQL before running the application. Verify the backup and the restored database before development.

### Security
Do not share `.env`, database passwords, production credentials, access tokens, or real customer data through a public repository. Grant repository access only to trusted collaborators.
