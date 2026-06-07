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
