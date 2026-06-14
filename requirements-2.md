# MileWorth — Requirements

> **MileWorth** is a mobile app that automatically tracks driving trips via GPS, classifies them as business or personal, and turns business miles into tax deductions. Drivers get accountant-ready PDF/CSV reports with zero manual effort.

**Tagline:** "Turn your miles into cash."

---

## 1. Project Snapshot

| Item | Decision |
|------|----------|
| App name | MileWorth |
| Package / bundle ID | `com.mileworth.app` (permanent once published — confirm before first release) |
| Frontend | Flutter (Android first; iOS later) |
| Backend | Node.js + Express REST API |
| Database | MongoDB (MongoDB Atlas, free M0 tier) |
| Backend hosting | Render or Railway (free tier) |
| Test distribution | Firebase App Distribution (not MediaFire) |
| Optional cloud build | Codemagic or GitHub Actions (keeps Intel Mac cool) |
| Monetization | Free tier + subscription (Google Play Billing) |
| Build approach | 3 phases, tested one at a time |

---

## 2. Architecture

MongoDB is a server database — the Flutter app must **not** connect to it directly. All data flows through the backend API:

```
Flutter app  ──HTTPS──>  Node.js + Express API  ──>  MongoDB Atlas
   (phone)                  (Render / Railway)         (cloud DB)
```

- The app calls REST endpoints (login, save trip, get trips, generate report).
- The backend holds the DB credentials and business logic; the phone never sees them.
- Auth via JWT (token stored securely on device).

---

## 3. Target Users

Self-employed / small-business drivers who deduct mileage on taxes: delivery & rideshare drivers, tradespeople (handyman, electrician), real-estate agents, traveling nurses, sales reps, freelancers.

---

## 4. Feature List (from reference screenshots)

### 4.1 Automatic GPS Tracking
- Detect drive start/stop automatically in the background (no manual start button).
- Record full route with start/end points on a map.
- "GPS Tracking Enabled" status indicator.
- Capture per trip: distance, start/end time, start/end location.
- Works while the app is closed/backgrounded.

### 4.2 Trip Classification
- Tag each trip **Business**, **Personal**, or **Uncategorized**.
- Quick swipe/toggle to switch business ↔ personal.
- Uncategorized trips flagged so none are missed.
- Color badges (blue = Business, yellow = Personal).

### 4.3 Trip Detail View
- Map of the drive with route line and start/end pins.
- Distance, timestamps, and dollar value of the deduction.
- Named start/end locations (Home, Home Depot, Job Site, Grocery Store, Airport).

### 4.4 Named / Recurring Locations
- Recognize and label frequent locations; name once, reuse.
- "Top Locations" list with trip counts and total value.

### 4.5 Deduction Calculation
- Business miles × configurable standard mileage rate = deduction value.
- Rate is a setting (changes yearly and by country) — never hardcoded.

### 4.6 Dashboard
- Total **Miles Tracked**, total **Work Drives** count, total **Tax Deductions** value.
- Totals update live.

### 4.7 Expense Tracking
- Add expenses: date, vendor, category, amount.
- Attach a receipt photo.
- Running expense total.

### 4.8 Reports
- PDF report (date range, line items, total).
- CSV / Excel export in one tap.
- Share with accountant via OS share sheet / email.

### 4.9 Insights
- Pie chart of drives by category with percentages.
- Category totals with trip counts and values.
- Top-locations ranking.

---

## 5. Functional Requirements

| ID | Requirement | Priority | Phase |
|----|-------------|----------|-------|
| FR-1 | Auto-detect drive start/stop in background | Must | 1 |
| FR-2 | Store distance, times, coordinates, route per trip | Must | 1 |
| FR-3 | Classify trip Business / Personal / Uncategorized | Must | 1 |
| FR-4 | Compute deduction = business miles × rate | Must | 1 |
| FR-5 | Dashboard totals (miles, trips, deductions) | Must | 1 |
| FR-6 | Manually add / edit a trip | Must | 1 |
| FR-7 | Add expense with vendor, category, amount, receipt photo | Should | 2 |
| FR-8 | Generate PDF report for a date range | Must | 2 |
| FR-9 | Export data to CSV | Should | 2 |
| FR-10 | Label and reuse recurring named locations | Should | 2 |
| FR-11 | Category pie chart + top-locations insights | Should | 3 |
| FR-12 | Share report via share sheet / email | Must | 2 |
| FR-13 | Work offline and sync when back online | Should | 3 |
| FR-14 | Auto-classification rules (e.g. weekends = personal) | Could | 3 |

---

## 6. Non-Functional Requirements

- **Battery:** Use motion/activity-recognition APIs to wake GPS only when driving — constant polling drains battery and is the #1 cause of bad reviews.
- **Permissions:** Request "Allow all the time" location with a clear explanation.
- **Privacy:** Location data stays private to the user; a published privacy policy is required for Play submission.
- **Reliability:** No dropped trips; queue and retry sync.
- **Performance:** Reports generate within a few seconds for hundreds of trips.
- **Accuracy:** Distance accurate enough for tax-record purposes.

---

## 7. Data Model (MongoDB collections)

```
users
  _id, email, passwordHash, mileageRate, currency,
  subscriptionStatus, createdAt

trips
  _id, userId, startTime, endTime, distance,
  startLat, startLng, endLat, endLng, routePolyline,
  category (business|personal|uncategorized),
  startLocationId, endLocationId, deductionValue

locations
  _id, userId, name, lat, lng, type (home|work|supplier|custom)

expenses
  _id, userId, date, vendor, category, amount, receiptImageUrl

reports
  _id, userId, dateRange, format (pdf|csv), generatedAt
```

---

## 8. API Endpoints (initial sketch)

```
POST  /auth/register
POST  /auth/login
GET   /trips                 (list user's trips)
POST  /trips                 (save a trip)
PATCH /trips/:id             (edit / reclassify)
GET   /trips/summary         (dashboard totals)
POST  /expenses              (add expense + receipt)
GET   /reports?from=&to=     (generate PDF/CSV)
GET   /locations / POST /locations
```

---

## 9. Monetization

- **Free tier:** limited automatic trips per month (e.g. 30–40) + basic totals.
- **Subscription (~$5–9/month or annual):** unlimited tracking, PDF/CSV reports, expense + receipt capture, insights, accountant sharing.
- **Paywall placement:** at peak perceived value — when the user exports a report or views their total deduction amount.
- Implemented with Google Play Billing.

---

## 10. Build Phases

**Phase 1 — Core (build + test fully first):**
FR-1, FR-2, FR-3, FR-4, FR-5, FR-6 + subscription scaffold.
Goal: detect a real drive, classify it, show a deduction total. Test on actual drives.

**Phase 2 — Reports & expenses:**
FR-7, FR-8, FR-9, FR-10, FR-12.

**Phase 3 — Insights & polish:**
FR-11, FR-13, FR-14.ho

Ship and test each phase before starting the next.

---

## 11. Dev Environment & Build (Intel MacBook Pro)

- Install Flutter SDK + Android Studio; run `flutter doctor` to verify.
- Skip iOS/Xcode setup initially — Android-only builds run much cooler.
- Use `flutter run` (debug) during development; do heavy release builds rarely.
- To avoid overheating on release builds, use cloud CI (Codemagic free tier ~500 min/month, or GitHub Actions) — also auto-distributes builds.
- Keep the Mac on a hard surface with airflow; close other heavy apps while building.

---

## 12. Distribution & Publishing Plan

**Testing:** Firebase App Distribution (free) — sends testers a link, tracks versions. Fits the phase-by-phase update plan.

**Publishing to Google Play (when Phase 1 is solid):**
- One-time $25 developer registration fee (vs Apple's $99/year).
- New personal accounts must run a **12-tester, 14-day closed test** before public release — line up 12 testers early; budget 2–4 weeks.
- Complete the Play **data-safety form**, especially the background-location justification (most common rejection cause for this app type).
- Publish an AAB (Android App Bundle), not an APK.

**Heads-up:** From September 2026, Google will require developer identity checks + the $25 fee even for apps installed on certified Android devices via sideloading — another reason to plan for the Play account rather than relying on file-download distribution.

**iOS (later):** requires Apple Developer Program ($99/year) and TestFlight for testing; you cannot sideload an IPA from a file download.

---

## 13. Key Risks

- **Background-location policy** — strict Play review; justify "all the time" access or get rejected.
- **Battery drain** — engineer GPS to trigger on motion, not run constantly.
- **Trip-detection accuracy** — the core hard problem (start/stop detection, ignoring walking, merging stops). Test heavily in the real world.
- **Mileage rates** vary by country and change yearly — make it a setting.
- **Tax wording** — present deductions as estimates; recommend users confirm with an accountant; avoid implying tax advice.
- **Name** — verify MileWorth in Play Console, App Store Connect, and a trademark search before committing the brand.
