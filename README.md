# MileWorth

> Automatically tracks driving trips via GPS, classifies them business/personal, and turns business miles into tax deductions. *"Turn your miles into cash."*

See [`requirements-2.md`](./requirements-2.md) for the full spec.

## Repository layout

```
app/        Flutter mobile app (Android first) — local-only, no account
backend/   Node.js + Express REST API  ->  MongoDB Atlas (deployed, not used by the app)
```

> **The shipped app is local-only.** It has no login and makes no API calls:
> trips, expenses, and preferences live on the device in `SharedPreferences`
> (`app/lib/services/local_store.dart`), and summaries, insights, and reports are
> computed on-device. The `backend/` service still exists and still deploys — it
> keeps its own tests and is available for a future sync/multi-device feature —
> but **no current app build talks to it**. Treat the two as independent until
> that changes.

## Build phases

- **Phase 1 — Core:** auto trip tracking, classification, deduction calc, dashboard, manual trips. *(done)*
- **Phase 2 — Reports & expenses:** CSV reports, expenses + receipts, sharing. *(done; PDF export needs a server and is not in the local-only build)*
- **Phase 3 — Insights & polish:** charts, auto-classification rules. *(done)*

## Getting started

### App
```bash
cd app
flutter pub get
flutter run               # against a connected Android device/emulator
```

No backend or configuration is needed — the app runs standalone. (Map tiles on
the trip-detail screen need a Google Maps API key; see `docs/MAPS_SETUP.md`.)

### Backend (optional — the app does not use it)

**With Docker (recommended — no database to install):**
```bash
docker compose up          # API on http://localhost:4000 + its own MongoDB
```
`docker-compose.yml` runs the API alongside a MongoDB container, so you need no
Atlas account and no local `mongod`. Source is bind-mounted and the server runs
under `node --watch`, so edits under `backend/src` restart it automatically.

```bash
curl http://localhost:4000/health   # {"status":"ok",...}
docker compose logs -f api          # verification / password-reset emails print here
docker compose down                 # stop;  add -v to also wipe the database
```

Data lives in the `mongo-data` volume and survives `down`/`up`. SMTP is
deliberately unset: the mailer logs emails to the container output instead of
sending them, so signup and password-reset flows work without a mail provider.

**Without Docker:**
```bash
cd backend
cp .env.example .env      # fill in MONGODB_URI (Atlas) and JWT_SECRET
npm install
npm run dev               # starts on http://localhost:4000
```

Either way, unit tests run on the host and need no database:
```bash
cd backend && npm test
```

> Docker here is for local development only. Render still deploys this service
> from its native Node runtime (`render.yaml`), so the container setup cannot
> affect production.

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

The current app build does not call this service, so there is no app-side step
after deploying.

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
(There is no `API_BASE_URL` to configure: the app is local-only and ignores it.)

Local release signing: copy `key.properties.example` → `android/key.properties`,
put your `.jks` at `android/app/upload-keystore.jks`. Both are gitignored.

