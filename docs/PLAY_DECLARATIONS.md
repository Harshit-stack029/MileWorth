# Play Console declarations — copy-paste answers

Two permission forms in Play Console need a written answer **and** a short
video. Both are about location. Fill them in when Play asks (it prompts you
after you upload the first `.aab`), at **Play Console → your app → Policy and
programs → App content**.

The app shows the required in-app explanation ("prominent disclosure") in two
places, both with the same wording from
`app/lib/widgets/background_location_disclosure.dart`:

- the last onboarding page, before **Enable automatic tracking**
- a dialog in **Settings → Automatic tracking**, before Android's prompt

---

## 1. Location permissions (background location)

**Where:** App content → **Sensitive app permissions** → *Location permissions*.

**Does your app access location in the background?** → Yes.

**Which feature needs it?** (pick from Play's list if offered) → *Mileage /
trip tracking* or describe as below.

**Describe the feature that uses background location (paste):**

> MileWorth is a mileage log for tax deductions. When the user turns on
> Automatic tracking, the app detects when a drive starts and records its route
> and distance until the drive ends, even if the app is closed or not in use.
> Drives start without warning while the phone is in a pocket or mount, so the
> app cannot rely on the user opening it first; background location is the core
> function of automatic mileage logging. A persistent notification is shown
> while tracking is on. Location is stored only on the device and is never
> transmitted to us or any third party. Users can turn Automatic tracking off at
> any time in Settings and still log trips manually.

**Why can't this work only while the app is open? (if asked, paste):**

> Users drive with the app closed. If location stopped when the app left the
> screen, drives would be missed or cut short, and the mileage log — which users
> rely on for tax records — would be incomplete.

## 2. Foreground service — location type

**Where:** App content → **Foreground service permissions**.

**Which foreground service types does your app use?** → **Location**.

**Describe the task (paste):**

> Records the GPS route and distance of a drive the user is taking, so it can be
> saved as a trip in their mileage log. The service starts when a drive begins
> (either the user taps Start, or Automatic tracking detects movement at driving
> speed) and stops when the drive ends. A notification is visible the whole time.

**What happens if the task is interrupted or deferred? (if asked):**

> The drive's distance would be recorded incorrectly or not at all, and the
> user's tax mileage log would be wrong. The task cannot be postponed, because
> the drive happens in real time.

---

## Video (one video can be used for both forms)

Play wants a link to a short video (≤ 30–60 seconds is plenty). Record your
phone's screen (pull down quick settings → **Screen record**), upload it to
YouTube as **Unlisted**, and paste the link into both forms.

**What to show, in order:**

1. Fresh install → open MileWorth → swipe through onboarding.
2. Stop on the last page so the disclosure text is readable for 2–3 seconds.
3. Tap **Enable automatic tracking** → Android's location prompt appears →
   choose **While using the app**, then on the next screen choose
   **Allow all the time**.
4. Show the **"MileWorth auto-tracking is on"** notification.
5. Go to the home screen (app closed), then show a recorded trip appearing in
   the Trips list. A short real drive is best; if not possible, show the
   Dashboard → **Start** → walk/drive a little → **Stop** → the trip.
6. (Optional) Settings → turn **Automatic tracking** off, to show it's
   user-controlled.

## Data safety form

Answers are in `docs/STORE_LISTING.md` → *Content / data safety*. Short version:
the app collects **no** data (nothing leaves the phone), unless you enable the
Google Maps key — see the note there.

## Other App content items (quick answers)

- **Ads:** No ads.
- **App access:** All functionality is available without special access (no
  login).
- **Content rating:** fill in the questionnaire — no violence, no user content,
  no gambling → rated Everyone / PEGI 3.
- **Target audience:** 18+ (it's a tax tool; avoids the extra Families rules).
- **News app:** No.
- **Health apps / Financial features:** Not a financial-services app (it does
  not move money or give loans). If asked, choose "My app doesn't provide any
  financial features".
- **Government app:** No.
