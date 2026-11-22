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

**Done in code (Nov 2026):** unused "physical activity" permission removed;
Play-compliant background-location disclosure shown before every location
prompt (onboarding + Settings); Privacy policy link in Settings; onboarding no
longer promises PDF export; route map hidden (instead of blank) when no Maps key;
CI signs every release build with one permanent key.

Still to do, in order:
- **Upload key → GitHub secrets.** The key is already generated and lives in
  `~/MileWorth-signing/` on your Mac (NOT in the repo). **Back that folder up**
  (e.g. to a USB stick or password manager). Then repo → Settings → Secrets and
  variables → Actions → **New repository secret**, twice:
  - `ANDROID_KEYSTORE_BASE64` = contents of `upload-keystore.base64.txt`
  - `ANDROID_KEY_PROPERTIES` = contents of `key.properties` (all 4 lines)
  The next `v*` tag build then produces the signed `.aab` for Play
  (Actions artifact **`mileworth-release-aab`**).
- ~~**Support email**~~ — done: `nexsevasolution@gmail.com` is in `docs/PRIVACY.md`.
  Use the same address as the contact email in Play Console.
- **Privacy policy URL:** live at
  `https://github.com/Harshit-stack029/MileWorth/blob/main/docs/PRIVACY.md`
  once this branch is merged into `main`.
- **Location forms + video:** answers and a recording script are in
  `docs/PLAY_DECLARATIONS.md`.
- **Data safety form:** answers in `docs/STORE_LISTING.md`.
- **Listing + assets:** copy in `docs/STORE_LISTING.md`; you still need the
  feature graphic (1024×500) and 2–8 screenshots.
- **Closed test:** new personal developer accounts must run a closed test with
  12+ testers for 14 days before production is unlocked.
- **Maps (optional):** set `MAPS_API_KEY` (see `docs/MAPS_SETUP.md`) to show
  route maps; without it the map is simply hidden.

## 6. ⚪ Subscriptions / billing — parked
There is no paywall and no purchase flow in the app; everything is free. The
server-side verification code still exists and is tested, so this is resumable,
but nothing is needed to launch. See `docs/BILLING_SETUP.md` if you want to bring
a Pro tier back.

---

## ❓ Questions for you (answer any time)
1. **Keep or retire the backend?** It deploys and costs a free-tier slot but no
   app build uses it. I've kept it active as you asked; say the word to retire it.
