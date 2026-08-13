# MileWorth — Launch Checklist (your wake-up TODO)

The app is **fully working end-to-end** and is now **local-only**: no account, no
login, no server. Trips, expenses and preferences live on the device, and every
feature is free. This list is everything left, in priority order. Items marked
**🔴 you only** need your accounts/hands (I can't do them); items marked
**🟢 ready** are done or I can finish on request.

---

## 1. 🔴 Security — rotate the database password (still do this)
Your Atlas password was exposed in chat and your DB is open to the internet.
**The app no longer uses the database, but the credential is still live and the
backend still deploys** — a leaked credential on an internet-open cluster is
worth closing regardless.
1. Atlas → **Database Access** → user `harishharshith029_db_user` → **Edit** →
   **Edit Password** → **Autogenerate** → copy → **Update User**.
2. Build the new connection string (swap the password between `:` and `@`).
3. Render → **mileworth-api** → **Environment** → update `MONGODB_URI` → Save
   (auto-redeploys).
4. Update `backend/.env` locally with the same value.

Full steps in `docs/SECURITY_RUNBOOK.md`. If you'd rather not maintain a server
you don't use, say so and I'll retire the Render service and the `backend/`
tree — the app is unaffected either way.

## 2. 🟢 Merge the branch → keep `main` current
On GitHub, merge the **`fix-login-crash`** pull request. It contains the
local-only rework, the backend hardening, the dependency cleanup, and these docs.
(Direct push to `main` is blocked by a review guardrail, so this one's a click
for you.)

## 3. 🟢 Install the app
Grab the latest build from the Actions tab → artifact
**`mileworth-universal-apk`** (installs on any phone) → **uninstall** the old
MileWorth → install. There's no server setup and no login: it opens straight into
the app.

> Uninstalling clears on-device data. Since there's no server copy, export a CSV
> from the Reports screen first if you have trips you want to keep.

## 4. ⚠️🔴 Test the core feature (driving) — READ THE CAVEAT
Manual tracking works. To test:
- Open the app → Dashboard → **Start** (GPS banner) → drive a short loop →
  **Stop** → confirm a trip appears with correct miles + a deduction value.

Background auto-start has a fix on the branch — the sentinel runs as a low-power
background service, so auto-mode *should* now catch drives with the app closed.
When auto-tracking is on you'll see a persistent "MileWorth auto-tracking is on"
notification (that's required by Android and is how it stays alive).
**Please drive-test this specifically:** enable auto-track, swipe the app away,
drive a loop, and check a trip was recorded. This is the one thing I cannot
verify for you.

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
  notes). Required by Play. It has been rewritten for the local-only app.
- **Listing + assets:** copy is ready in `docs/STORE_LISTING.md`. You still need
  to create the feature graphic (1024×500) and 2–8 screenshots.
- **Data safety form:** answers are pre-written in `docs/STORE_LISTING.md`. They
  now declare **no data collection**, which is what the app actually does —
  don't over-declare, the form must match real behaviour.
- **Maps API key:** the trip-route map needs `MAPS_API_KEY` set as a repo secret
  or the map tiles won't load (see `docs/MAPS_SETUP.md`).

## 6. ⚪ Subscriptions / billing — parked
There is no paywall and no purchase flow in the app; everything is free. The
server-side verification code still exists and is tested, so this is resumable,
but nothing is needed to launch. See `docs/BILLING_SETUP.md` if you want to bring
a Pro tier back.

---

## ❓ Questions for you (answer any time)
1. **Contact email** for the privacy policy / store listing? (I used a
   placeholder `support@mileworth.app` — Play requires a real one you monitor.)
2. **Keep or retire the backend?** It deploys and costs a free-tier slot but no
   app build uses it. I've kept it active as you asked; say the word to retire it.
3. Want me to set up the **one-off GitHub Action to generate your keystore** so
   you don't need Java locally?
