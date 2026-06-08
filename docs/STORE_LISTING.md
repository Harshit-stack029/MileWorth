# MileWorth — Google Play Store Listing (draft)

Copy/paste these into Play Console → your app → **Main store listing**. Character
limits are noted; everything below is within them. Tweak the voice to taste.

## App name (max 30 chars)
```
MileWorth: Mileage Tracker
```
(26 chars. Alternative: `MileWorth — Mileage to Cash` = 27)

## Short description (max 80 chars)
```
Auto-track drives by GPS and turn business miles into tax deductions.
```
(69 chars)

## Full description (max 4000 chars)
```
Turn your miles into cash.

MileWorth automatically tracks your driving trips using GPS, sorts them into
business or personal, and turns your business miles into estimated tax
deductions — so you never miss a write-off again.

WHY MILEWORTH
• Automatic GPS trip tracking — drives are detected and recorded for you.
• Business vs. personal classification with one tap (or automatic rules).
• Instant deduction estimates using the current IRS standard mileage rate.
• A clear dashboard showing your miles, work drives, and total deductions.
• PDF and CSV reports you can hand to your accountant or attach to your taxes.
• Expense tracking with receipt photos.
• Insights into your driving by category and top locations.
• Works offline — trips sync automatically when you're back online.

PERFECT FOR
Rideshare and delivery drivers, real estate agents, sales reps, contractors,
freelancers, small-business owners, and anyone who drives for work.

HOW IT WORKS
1. Create a free account.
2. Allow location access so MileWorth can detect your drives.
3. Drive — your trips are recorded and your deductions add up automatically.
4. Review, classify, and export when tax time comes.

LOCATION
MileWorth uses location in the background only to record your drives and measure
distance. You're always in control and can turn tracking off any time.

Disclaimer: deduction figures are estimates. Always confirm with a qualified tax
professional before filing.
```

## Required graphical assets (you must create these)
- **App icon:** 512×512 PNG (you already have the brand mark in `assets/brand/`).
- **Feature graphic:** 1024×500 PNG (banner shown at the top of the listing).
- **Phone screenshots:** at least 2 (up to 8), 16:9 or 9:16, min 320px side.
  Good ones to capture: the dashboard with deductions, the trips list, a trip
  detail, and the insights screen.

## Categorization
- **Category:** Finance (or Business)
- **Tags:** mileage, tax, deductions, GPS, expenses

## Content / data safety (Play Console → App content)
You'll fill the **Data safety** form. Be ready to declare:
- Collects: email, precise location (incl. background), photos (receipts),
  purchase history.
- Purpose: app functionality, account management.
- Encrypted in transit: yes (HTTPS). Users can request deletion: yes.
- No data shared with third parties for advertising.

## Privacy policy URL
Required. Host `docs/PRIVACY.md` and paste the URL here. Easiest options:
- **GitHub Pages:** repo Settings → Pages → deploy from `main`/`docs` → the file
  is served at `https://harshit-stack029.github.io/MileWorth/PRIVACY` (after a
  quick Markdown→HTML step or by renaming to an `.html`/index).
- **Render static page** or any free host (Netlify, GitHub Gist rendered, etc.).
