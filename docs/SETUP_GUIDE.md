# Construction Management System — Complete Setup Guide

---

## Project Structure

```
construction_system/
├── backend/                        # FastAPI Python backend
│   ├── app/
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   └── models.py           # All SQLAlchemy models
│   │   ├── routes/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py             # Login, register, user management
│   │   │   ├── inventory.py        # Items, categories, warehouses
│   │   │   ├── projects.py         # Projects + material assignment
│   │   │   ├── purchases.py        # Purchases + suppliers
│   │   │   └── reports.py          # Dashboard + reporting
│   │   ├── schemas/
│   │   │   ├── __init__.py
│   │   │   └── schemas.py          # All Pydantic schemas
│   │   ├── utils/
│   │   │   ├── __init__.py
│   │   │   └── auth.py             # JWT, password hashing, guards
│   │   ├── __init__.py
│   │   ├── config.py               # Settings from .env
│   │   └── database.py             # Async SQLAlchemy + init_db
│   ├── .env                        # Environment variables
│   ├── main.py                     # FastAPI app + router registration
│   ├── requirements.txt
│   ├── seed.py                     # Sample data seeder
│   └── construction.db             # SQLite DB (auto-created)
│
├── flutter_app/                    # Flutter Android application
│   ├── lib/
│   │   ├── main.dart               # Entry point + auth gate
│   │   ├── models/
│   │   │   └── models.dart         # All Dart data models
│   │   ├── services/
│   │   │   ├── api_service.dart    # All HTTP calls to backend
│   │   │   └── auth_provider.dart  # Auth state (ChangeNotifier)
│   │   ├── navigation/
│   │   │   └── app_router.dart     # Route definitions + nav shell
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── auth/
│   │   │   │   └── login_screen.dart
│   │   │   ├── dashboard/
│   │   │   │   └── dashboard_screen.dart
│   │   │   ├── inventory/
│   │   │   │   ├── inventory_list_screen.dart
│   │   │   │   └── add_edit_inventory_screen.dart
│   │   │   ├── projects/
│   │   │   │   ├── projects_list_screen.dart
│   │   │   │   ├── project_detail_screen.dart
│   │   │   │   └── project_form_screen.dart
│   │   │   ├── purchases/
│   │   │   │   ├── purchase_list_screen.dart
│   │   │   │   └── purchase_form_screen.dart
│   │   │   ├── reports/
│   │   │   │   └── reports_screen.dart
│   │   │   └── suppliers/
│   │   │       └── suppliers_screen.dart
│   │   ├── utils/
│   │   │   └── constants.dart      # Colors, theme, base URL
│   │   └── widgets/
│   │       └── common_widgets.dart # Shared UI components
│   ├── android/
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml
│   │       └── res/
│   │           ├── xml/network_security_config.xml
│   │           ├── values/styles.xml
│   │           └── drawable/launch_background.xml
│   ├── assets/images/
│   └── pubspec.yaml
│
└── docs/
    ├── API_DOCUMENTATION.md
    └── SETUP_GUIDE.md              # This file
```

---

## Part 1 — Backend Setup & Local Run

### Prerequisites
- Python 3.10 or higher
- pip

### Step 1 — Install dependencies
```bash
cd construction_system/backend
pip install -r requirements.txt
```

### Step 2 — Configure environment
The `.env` file is already present with safe defaults for local development.
For production, change `SECRET_KEY` to a random 32+ character string:
```bash
# Generate a secure key:
python3 -c "import secrets; print(secrets.token_hex(32))"
```

### Step 3 — Seed the database with sample data
```bash
python seed.py
```
Output:
```
✅ Database seeded successfully!
📋 Login Credentials:
   Admin   → username: admin    | password: Admin@123
   Manager → username: manager  | password: Manager@123
   Worker  → username: worker   | password: Worker@123
📦 Seeded: 22 inventory items across 9 categories
         3 suppliers, 2 purchases, 3 projects
         6 material usage records
```

### Step 4 — Run the API server
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Step 5 — Verify it works
```
http://localhost:8000/health      → {"status":"healthy"}
http://localhost:8000/docs        → Swagger UI (full interactive docs)
http://localhost:8000/redoc       → ReDoc API docs
```

### Quick API test (curl)
```bash
# Login
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Get inventory
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/v1/inventory/items

# Dashboard
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/v1/reports/dashboard
```

---

## Part 2 — Flutter App Setup

### Prerequisites
- Flutter SDK 3.19+  (https://flutter.dev/docs/get-started/install)
- Android Studio or VS Code with Flutter extension
- Android SDK (API 21+)
- Either: Android emulator OR physical Android device

### Step 1 — Install Flutter dependencies
```bash
cd construction_system/flutter_app
flutter pub get
```

### Step 2 — Configure backend URL

Open `lib/utils/constants.dart` and set `baseUrl`:

| Scenario | URL to use |
|----------|-----------|
| Android Emulator (same machine) | `http://10.0.2.2:8000/api/v1` ✅ (default) |
| Physical device (same WiFi) | `http://192.168.1.X:8000/api/v1` |
| Production server | `https://yourdomain.com/api/v1` |

```dart
// lib/utils/constants.dart
static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
```

### Step 3 — Run on emulator / device
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d emulator-5554

# Run in release mode (faster)
flutter run --release
```

---

## Part 3 — Build Android APK

### Debug APK (for testing)
```bash
cd construction_system/flutter_app
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (for production/distribution)

**Step 1 — Create a keystore** (only once):
```bash
keytool -genkey -v -keystore ~/construction-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias construction-key
```

**Step 2 — Create key.properties** in `flutter_app/android/`:
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=construction-key
storeFile=/home/your_username/construction-keystore.jks
```

**Step 3 — Configure build.gradle** (`android/app/build.gradle`):
```groovy
android {
    ...
    signingConfigs {
        release {
            def keystoreProperties = new Properties()
            def keystorePropertiesFile = rootProject.file('key.properties')
            if (keystorePropertiesFile.exists()) {
                keystorePropertiesFile.withInputStream { keystoreProperties.load(it) }
            }
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

**Step 4 — Build:**
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

**Step 5 — Install on device:**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### App Bundle (for Google Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

---

## Part 4 — Backend Deployment (Production)

### Option A: Deploy to Ubuntu VPS (DigitalOcean / AWS EC2 / Hetzner)

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y
sudo apt install python3-pip python3-venv nginx -y

# 2. Clone/upload your project
scp -r construction_system/ user@your-server:/home/user/

# 3. Create virtual environment
cd /home/user/construction_system/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 4. Set production environment
nano .env
# Change:
# DATABASE_URL=postgresql+asyncpg://user:pass@localhost/construction_db
# SECRET_KEY=<your-32-char-random-secret>
# DEBUG=False

# 5. Install and configure PostgreSQL (recommended for production)
sudo apt install postgresql postgresql-contrib -y
sudo -u postgres psql
  CREATE USER constr_user WITH PASSWORD 'secure_pass';
  CREATE DATABASE construction_db OWNER constr_user;
  \q

pip install asyncpg  # PostgreSQL async driver

# 6. Create systemd service
sudo nano /etc/systemd/system/construction-api.service
```

```ini
[Unit]
Description=Construction Management API
After=network.target

[Service]
User=www-data
WorkingDirectory=/home/user/construction_system/backend
Environment="PATH=/home/user/construction_system/backend/venv/bin"
ExecStart=/home/user/construction_system/backend/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable construction-api
sudo systemctl start construction-api

# 7. Configure Nginx as reverse proxy
sudo nano /etc/nginx/sites-available/construction
```

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/construction /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# 8. Add HTTPS with Certbot (free SSL)
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d your-domain.com

# 9. Seed production database
cd /home/user/construction_system/backend
source venv/bin/activate
python seed.py
```

### Option B: Railway / Render (PaaS — easiest)

1. Push backend to GitHub
2. Create new project on [railway.app](https://railway.app) or [render.com](https://render.com)
3. Add PostgreSQL plugin
4. Set environment variables:
   - `DATABASE_URL` = provided by platform
   - `SECRET_KEY` = your secret
   - `DEBUG` = False
5. Set start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
6. Deploy and get your public URL
7. Update Flutter `baseUrl` to your public URL

---

## Part 5 — Database Migration (SQLite → PostgreSQL)

```bash
# 1. Install asyncpg
pip install asyncpg

# 2. Update .env
DATABASE_URL=postgresql+asyncpg://user:pass@localhost/construction_db

# 3. Tables are auto-created by init_db() on first run
# 4. Re-run seed.py to populate sample data
python seed.py
```

---

## Credentials Summary

| Role | Username | Password | Permissions |
|------|----------|----------|-------------|
| Admin | `admin` | `Admin@123` | Full access — register users, delete items |
| Manager | `manager` | `Manager@123` | Full access except user management |
| Worker | `worker` | `Worker@123` | Read + create inventory, assign materials |

---

## Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| `Connection refused` on emulator | Use `10.0.2.2:8000` not `localhost:8000` |
| `Connection refused` on real device | Use your machine's LAN IP (e.g. `192.168.1.5`) |
| `cleartext not permitted` | Verify `network_security_config.xml` is referenced in `AndroidManifest.xml` |
| `ModuleNotFoundError` | Run `pip install -r requirements.txt` in backend folder |
| `greenlet` conflict | Run `pip install greenlet==3.1.1 --break-system-packages` |
| Token expired | Token lasts 7 days by default. Log in again or increase `ACCESS_TOKEN_EXPIRE_MINUTES` in `.env` |
| Low stock items not showing | Check `min_quantity` is set > 0 on inventory items |
