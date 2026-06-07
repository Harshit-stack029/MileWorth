# MileWorth

> Automatically tracks driving trips via GPS, classifies them business/personal, and turns business miles into tax deductions. *"Turn your miles into cash."*

See [`requirements-2.md`](./requirements-2.md) for the full spec.

## Repository layout

```
backend/   Node.js + Express REST API  ->  MongoDB Atlas
app/        Flutter mobile app (Android first)
```

The Flutter app never talks to MongoDB directly — all data flows through the backend API over HTTPS (see Architecture in the requirements).

## Build phases

- **Phase 1 — Core:** auto trip tracking, classification, deduction calc, dashboard, manual trips. *(in progress)*
- **Phase 2 — Reports & expenses:** PDF/CSV reports, expenses + receipts, named locations, sharing.
- **Phase 3 — Insights & polish:** charts, offline sync, auto-classification rules.

## Getting started

### Backend
```bash
cd backend
cp .env.example .env      # fill in MONGODB_URI (Atlas) and JWT_SECRET
npm install
npm run dev               # starts on http://localhost:4000
```

### App
```bash
cd app
flutter pub get
flutter run               # against a connected Android device/emulator
```

Point the app at the backend via `--dart-define=API_BASE_URL=http://10.0.2.2:4000` (Android emulator) or your machine's LAN IP on a physical device.

## Deploying the backend to Render

The repo ships a [`render.yaml`](./render.yaml) Blueprint that provisions the API
as a free Render web service.

1. **Push to GitHub.** Render deploys from a git remote, so push this repo first.
2. **Atlas network access.** In MongoDB Atlas → Network Access, add `0.0.0.0/0`
   (allow from anywhere). Render's free tier uses dynamic outbound IPs, so an IP
   allowlist won't work. The connection is still authenticated by the URI
   credentials.
3. **Create the service.** In Render → **New → Blueprint**, select the repo.
   Render reads `render.yaml` and creates the `mileworth-api` web service
   (`rootDir: backend`, `npm ci` → `npm start`, health check at `/health`).
4. **Set the secret env var.** When prompted, paste your full Atlas connection
   string (including `/mileworth`) into **`MONGODB_URI`**. `JWT_SECRET` is
   auto-generated; the rest have defaults. `PORT` is injected by Render.
5. **Deploy & verify.** Once live, hit `https://<your-service>.onrender.com/health`
   — it should return `{"status":"ok"}`.
6. **Point the app at it.**
   ```bash
   flutter run --dart-define=API_BASE_URL=https://<your-service>.onrender.com
   ```

> **Free-tier note:** the service spins down after ~15 min idle, so the first
> request after a pause takes a few seconds to cold-start. Upgrade the plan in
> `render.yaml` (`plan: starter`) to keep it always-on.

## CI / cloud builds (GitHub Actions)

Two workflows live in `.github/workflows/`:

- **`ci.yml`** — runs on every push/PR to `main`: backend `npm test` and
  Flutter `analyze` + `test`. No secrets needed.
- **`android.yml`** — manual (Actions → Run workflow) or on a `v*` tag. Builds a
  debug APK artifact always; builds a **signed release AAB** and pushes to
  **Firebase App Distribution** when the secrets below are set. Building in the
  cloud keeps release builds off your Intel Mac (requirements §11).

### One-time setup for signed release builds

1. **Generate an upload keystore** (once, keep it safe — losing it means you
   can't update the app):
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```
2. **Add repo secrets** (GitHub → Settings → Secrets and variables → Actions):
   | Secret | Value |
   |--------|-------|
   | `ANDROID_KEYSTORE_BASE64` | `base64 -i upload-keystore.jks` output |
   | `ANDROID_KEY_PROPERTIES` | contents of your `android/key.properties` (see `key.properties.example`) |
   | `FIREBASE_APP_ID` | Firebase Android app ID (optional, for distribution) |
   | `FIREBASE_SERVICE_ACCOUNT` | Firebase service-account JSON (optional) |
3. **Add a repo variable** `API_BASE_URL` = your Render URL, so release builds
   point at production.

Local release signing: copy `key.properties.example` → `android/key.properties`,
put your `.jks` at `android/app/upload-keystore.jks`. Both are gitignored.

