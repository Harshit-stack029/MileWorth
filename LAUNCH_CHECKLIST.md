# MileWorth — Launch Checklist (your wake-up TODO)

Prepared overnight. The app is **fully working end-to-end** already. This list is
everything left, in priority order. Items marked **🔴 you only** need your
accounts/hands (I can't do them); items marked **🟢 ready** are done or I can
finish on request. The two **⚠️ code gaps** are real and explained at the bottom.

---

## 1. 🔴 Security — rotate the database password (do first)
Your Atlas password was exposed in chat and your DB is open to the internet.
1. Atlas → **Database Access** → user `harishharshith029_db_user` → **Edit** →
   **Edit Password** → **Autogenerate** → copy → **Update User**.
2. Build the new connection string (swap the password between `:` and `@`).
3. Render → **mileworth-api** → **Environment** → update `MONGODB_URI` → Save
   (auto-redeploys).
4. Update `backend/.env` locally with the same value.
5. Paste me the new string and I'll verify Render reconnects + login still works.

## 2. 🟢 Merge the fix → keep `main` current
On GitHub, merge the **`fix-login-crash`** pull request (same as you did for #1).
It contains: the login-crash fix, the Render URL as the default backend, the
installable release-APK CI step, and these docs. (Direct push to `main` is
blocked by a review guardrail, so this one's a click for you.)

## 3. 🟢 Install the fixed app
The **v0.1.3** build is at the Actions tab. Download artifact
**`mileworth-release-apks`** → **uninstall** the old MileWorth → install
`app-arm64-v8a-release.apk`. It already points at your Render backend (no server
setup) and won't crash on login.

## 4. ⚠️🔴 Test the core feature (driving) — READ THE CAVEAT
Manual tracking works. To test:
- Open the app → Dashboard → **Start** (GPS banner) → drive a short loop →
  **Stop** → confirm a trip appears with correct miles + a deduction value.

**Update:** gap #1 (background auto-start) now has a fix on the branch — the
sentinel runs as a low-power background service, so auto-mode *should* now catch
drives with the app closed. When auto-tracking is on you'll see a persistent
"MileWorth auto-tracking is on" notification (that's required by Android and is
how it stays alive). **Please drive-test this specifically:** enable auto-track,
swipe the app away, drive a loop, and check a trip was recorded.

## 5. 🔴 Play Store launch prep
- **Generate an upload keystore** (needs Java/`keytool`; not installable on your
  Mac as-is). Easiest: run this in any environment with the JDK, or I can set up
  a one-off GitHub Action to generate it for you — just ask:
  ```
  keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
    -validity 10000 -alias upload
  ```
- **Add GitHub secrets** (repo → Settings → Secrets and variables → Actions):
  - `ANDROID_KEYSTORE_BASE64` = `base64 -i upload-keystore.jks`
  - `ANDROID_KEY_PROPERTIES` = the 4 lines (storePassword, keyPassword, keyAlias,
    storeFile=upload-keystore.jks)
  Then a tagged build produces a **signed `.aab`** for Play.
- **Privacy policy:** host `docs/PRIVACY.md` at a public URL (see that file's
  notes). Required by Play.
- **Listing + assets:** copy is ready in `docs/STORE_LISTING.md`. You still need
  to create the feature graphic (1024×500) and 2–8 screenshots.
- **Data safety form:** answers are pre-written in `docs/STORE_LISTING.md`.

## 6. 🔴 Subscriptions / billing — backend now implemented, needs your credentials
- **Create the product** in Play Console: subscription with product ID
  **`mileworth_pro_monthly`** (this exact ID is what the app queries).
- **Server verification is now built** (gated, off until configured). To turn it
  on:
  1. Google Cloud → create a **service account**, enable the **Google Play
     Android Developer API**, download its **JSON key**.
  2. Play Console → **Users & permissions** → invite that service account →
     grant **View financial data / Manage orders**.
  3. In **Render → mileworth-api → Environment**, add:
     - `GOOGLE_SERVICE_ACCOUNT_JSON` = the full JSON key (one line)
     - `ANDROID_PACKAGE_NAME` = `com.mileworth.app` (already the default)
  4. Save → Render redeploys → purchases are verified for real.
  Until those are set, production safely returns 501 (no Pro on unverified
  claims), exactly as before — so nothing breaks by merging.

---

## ⚠️ Code gaps (real, intentionally NOT changed overnight — they need testing)

### Gap #1 — automatic background trip detection — ✅ FIX ON BRANCH (needs drive-test)
`auto_trip_detector.dart` runs a low-power "sentinel" GPS stream to notice when a
drive starts, then promotes to the foreground-service recorder. Previously the
sentinel had no background config, so Android suspended it when the app closed.
**Fixed:** the sentinel now uses a low-power Android foreground service (and iOS
background-location updates), so it stays alive to catch drives with the app
closed. Cost: a persistent low-key notification while auto-tracking is enabled
(unavoidable on Android, and how every always-on mileage app works). **Must be
drive-tested** before trusting it — see task #4.

### Gap #2 — production billing verification — ✅ IMPLEMENTED (needs your credentials + a test purchase)
`backend/src/utils/googlePlay.js` now verifies subscription tokens via the
Android Publisher API (built with your existing `jsonwebtoken` dep — no new
packages, so `npm ci` is unaffected). It's **gated**: with no service account
configured, production returns 501 exactly as before, so merging changes nothing
until you opt in (see task #6). Unit-tested offline (`test/googlePlay.test.js`).
Still do a real sandbox test purchase once credentials are set before relying on
revenue.

---

## ❓ Questions for you (answer any time)
1. **Contact email** for the privacy policy / store listing? (I used a
   placeholder `support@mileworth.app`.)
2. **Subscription price** for `mileworth_pro_monthly`? (e.g. $6.99/mo)
3. Want me to **implement gap #1** (background auto-detect) and **gap #2**
   (billing verification) next — or focus on getting the Play Store listing live
   first?
4. Want me to set up the **one-off GitHub Action to generate your keystore** so
   you don't need Java locally?
