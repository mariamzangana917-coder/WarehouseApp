Flutter:  انسخي مجلد flutter/lib فوق lib الحالي (يستبدل main.dart ويضيف مجلد src).
          ما يحتاج تغيير pubspec.yaml (نفس الحزم: http فقط).
          عنوان الخادم: --dart-define=WAREHOUSE_API_URL=http://IP:8000/api
Laravel:  انسخي مجلد laravel فوق المشروع، بعدها:
          php artisan migrate
          php artisan db:seed
          php artisan config:clear
