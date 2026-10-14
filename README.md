# WarehouseApp — Developer Handover

## Project structure

- Laravel API: repository root
- Flutter application: `app_flutter/`
- Database engine: PostgreSQL
- Database name: `warehouse_app`
- PostgreSQL backup: `database_backup/warehouse_app.backup`

## Prerequisites

Install Git, a PHP version compatible with the project, Composer,
PostgreSQL, Flutter SDK, and Android Studio or another Flutter IDE.

Check the Laravel version and its PHP requirements in `composer.json`.

## 1. Clone the repository

```powershell
git clone https://github.com/mariamzangana917-coder/WarehouseApp.git
cd WarehouseApp
```

## 2. Configure PostgreSQL

Create an empty database named `warehouse_app` using PostgreSQL.

Restore the supplied custom-format backup into that empty database.
For example, from the repository root:

```powershell
pg_restore --username=postgres --dbname=warehouse_app --no-owner --no-privileges ".\database_backup\warehouse_app.backup"
```

Adjust the PostgreSQL username and executable path for your computer.
The command may prompt for the PostgreSQL password.

Verify that the restore completed and that the expected tables and data exist.
Do not restore into a database containing data you need to preserve.

## 3. Configure Laravel

From the repository root:

```powershell
composer install
Copy-Item .env.example .env
```

Edit `.env` locally and configure the PostgreSQL connection:

- `DB_CONNECTION=pgsql`
- `DB_HOST=127.0.0.1`
- `DB_PORT=5432`
- `DB_DATABASE=warehouse_app`
- `DB_USERNAME` and `DB_PASSWORD` for your local PostgreSQL account

Then run:

```powershell
php artisan key:generate
php artisan config:clear
php artisan serve --host=0.0.0.0 --port=8000
```

The database backup already contains database objects and data. Do not run
migrations or seeders automatically against the restored database without
checking the project's migrations and seeder behavior first.

## 4. Configure and run Flutter

Open a second terminal:

```powershell
cd app_flutter
flutter pub get
flutter run --dart-define=WAREHOUSE_API_URL=http://YOUR_HOST_IP:8000/api
```

Replace `YOUR_HOST_IP` with the reachable IP address of the computer
running Laravel.

For an Android emulator, `http://10.0.2.2:8000/api` commonly reaches the
host computer. For a physical device, use the host computer's LAN IP and
ensure both devices can communicate over the network.

The Flutter default URL may point to the original developer's computer;
always configure the URL for the current environment.

## 5. Final verification

- Confirm Laravel starts without errors.
- Confirm PostgreSQL tables and data are present.
- Confirm the API is reachable from the target device.
- Run `flutter analyze` and the available Flutter tests.
- Test the main catalog flows before continuing development.

## Security

- Never commit `.env`, passwords, access tokens, or production credentials.
- Keep this repository private and grant access only to trusted collaborators.
- Use a separate, verified backup before changing or restoring important data.
