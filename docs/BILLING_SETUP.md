# MileWorth — Google Play Billing Production Setup

The verification **code** is done (`backend/src/utils/googlePlay.js`, unit-tested).
Until the steps below are completed, `POST /billing/verify` returns **501** in
production and Pro is never granted — which is the safe default.

The app buys product id **`mileworth_pro_monthly`** (see
`app/lib/services/subscription_service.dart`). The package id is
**`com.mileworth.app`**.

## 1. Create the subscription product in Play Console

1. **Play Console → your app → Monetize → Products → Subscriptions**.
2. **Create subscription**. Product ID: **`mileworth_pro_monthly`** (must match exactly).
3. Add a base plan (monthly, auto-renewing), set the price, **Activate**.

## 2. Create a service account for the Android Publisher API

1. **Google Cloud Console → APIs & Services → Library** → enable **Google Play Android Developer API**.
2. **IAM & Admin → Service Accounts → Create service account** (e.g. `mileworth-billing`).
3. On the new account: **Keys → Add key → Create new key → JSON**. A JSON file downloads — keep it secret.
4. **Play Console → Users and permissions → Invite new user**, enter the service-account email, grant
   **View financial data, orders, and cancellation survey responses** (account-level), and app access to MileWorth. Save.

## 3. Put the service account into Render

1. Open the downloaded JSON, copy its **entire contents onto one line**.
2. **Render → mileworth-api → Environment → Add Environment Variable**:
   - `GOOGLE_SERVICE_ACCOUNT_JSON` = the one-line JSON
   - `ANDROID_PACKAGE_NAME` = `com.mileworth.app`
3. **Save Changes** → wait for redeploy.

## 4. Verify

```
curl https://mileworth-api.onrender.com/health
```
`"billingConfigured": true` confirms the JSON parsed and the account is wired.
(If you pasted malformed JSON, the deploy logs print a
`[googlePlay] GOOGLE_SERVICE_ACCOUNT_JSON could not be parsed` error and
`billingConfigured` stays `false`.)

Then do a **real sandbox purchase**: add a license tester
(**Play Console → Setup → License testing**), install the signed build, buy Pro,
and confirm the account flips to `active`.

## Known follow-up (not blocking first launch)

There is **no renewal/cancellation handling yet** — `subscriptionStatus` is set
to `active` on purchase but never flips back when a user cancels or a renewal
fails. Before relying on recurring revenue, add one of:
- **Real-time Developer Notifications** (Pub/Sub) → a webhook that updates status, or
- a periodic re-verify job that calls `verifySubscription` and downgrades expired users.

This is tracked as a Phase-2 item.
