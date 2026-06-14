# MileWorth — Security Runbook

Operational steps that must be done in the **Atlas** and **Render** dashboards.
Code-side protections (no committed secrets, production refuses weak `JWT_SECRET`,
billing never grants Pro without verification) are already in place.

## 1. Rotate the leaked MongoDB password  ⚠️ do this first

1. Go to **MongoDB Atlas → Database Access** (left sidebar).
2. Find the database user in your connection string. Click **Edit**.
3. Click **Edit Password → Autogenerate Secure Password → Copy**. Save it somewhere safe for a moment.
4. Click **Update User**.
5. Rebuild your connection string with the new password:
   `mongodb+srv://USER:NEW_PASSWORD@cluster0.xxxxx.mongodb.net/mileworth?retryWrites=true&w=majority`
   (keep the `/mileworth` database name).

## 2. Put the new connection string into Render

1. Go to **Render → your `mileworth-api` service → Environment**.
2. Edit **`MONGODB_URI`**, paste the new string, **Save Changes**.
3. Render redeploys automatically. Wait for "Live".

## 3. Lock down Atlas network access

1. **Atlas → Network Access → IP Access List**.
2. **Delete** any `0.0.0.0/0` ("allow from anywhere") entry.
3. Add Render's outbound IPs (Render dashboard → your service → **Connect / Outbound** shows them), or — simplest on the free tier — keep a single temporary `0.0.0.0/0` ONLY if you cannot get static IPs, and plan to move to a paid tier with static outbound IPs.

## 4. (Optional) Rotate the JWT secret

`render.yaml` sets `JWT_SECRET` with `generateValue: true`, so Render already
generated a strong one. **Rotating it logs every user out** (existing tokens
become invalid). Only do this if you suspect the secret leaked:
1. **Render → Environment → `JWT_SECRET` → Regenerate** (or set a new 40+ char random value).
2. Save → redeploy.

## 5. Verify the live deployment

```
curl https://mileworth-api.onrender.com/health
```
Expect:
```json
{ "status":"ok", "env":"production", "billingConfigured":false,
  "mockBilling":false, "emailConfigured":false }
```
- `env` must be `production`.
- `mockBilling` must be `false` (else free Pro is being handed out).
- After Task 8 + email setup, `billingConfigured` / `emailConfigured` flip to `true`.

If the server fails to start after a deploy, check the logs: a weak/placeholder
`JWT_SECRET` now **intentionally** crashes the boot (see `src/config/env.js`).
