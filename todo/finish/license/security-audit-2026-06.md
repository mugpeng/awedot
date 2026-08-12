# License Security Audit — 2026-06-20

Comprehensive security review of the awedot licensing system, covering the Tauri client, Vercel serverless API, Supabase backend, and admin CLI.

---

## Architecture Overview

```
Client (Tauri)                           Server (Vercel / Supabase)
  ├── src/lib/license.ts                     ├── api/verify.js
  ├── src-tauri/src/license/mod.rs           ├── api/deactivate.js
  │   ├── verify_license()                   ├── api/trial/start.js
  │   ├── deactivate_license()               ├── api/trial/status.js
  │   ├── start_trial()                      └── api/webhook/lemonsqueezy.js (disabled)
  │   └── get_license_status()
  │
  ├── src/components/LicensePanel.tsx        └── awedot-admin db CLI
  │   └── License key input & activation        (Supabase service_role)
  │
  └── src/components/Panel.tsx
      ├── FREE_BOOKMARK_LIMIT = 5 (frontend only)
      └── FREE_SESSION_LIMIT = 2 (frontend only)
```

---

## Findings

### P1 — Deactivate endpoint lacks device ownership verification

**File:** `product/tools/awedot-dev/api/deactivate.js:10-36`

**Problem:** Any caller who knows a license key can POST an arbitrary `device_id` to deactivate the currently bound device. The endpoint only checks that the key exists and that the caller's `device_id` matches the bound device — but if `activated_device_id` is null (race condition or data inconsistency), the deactivation succeeds unconditionally.

**Attack path:**
1. Attacker obtains a valid license key (e.g., from a public share, purchase, or leaked list)
2. Attacker calls `POST /api/deactivate` with `{ key, device_id: "any-string" }`
3. Victim's device is unbound; attacker then calls `verify` with their own `device_id` and steals the seat

**Fix:** Require proof of device ownership — either a challenge-response signed by the Tauri app's keychain secret, or restrict deactivation to the device that originally activated (verify the caller's `device_id` matches `activated_device_id` before allowing deactivation). Alternatively, only allow deactivation via LemonSqueezy webhook (purchase cancellation/refund).

---

### P2 — LemonSqueezy webhook disabled, no signature verification planned

**File:** `product/tools/awedot-dev/api/webhook/lemonsqueezy.js`

**Problem:** The webhook handler is a no-op that returns `{ received: true, disabled: true }`. The TODO comment acknowledges that `X-Signature` HMAC verification must be added when enabled. Without it, anyone who discovers the endpoint URL can POST forged webhook events to grant themselves license activations.

**Current impact:** Low (endpoint does nothing). **Future risk:** Critical when webhook is enabled without signature validation.

**Fix:** Before enabling, implement HMAC-SHA256 verification using the LemonSqueezy webhook signing secret. Validate `X-Signature` header against request body before processing any event.

---

### P3 — Free-tier limits enforced only in frontend

**Files:**
- `product/tools/awedot/src/components/Panel.tsx:366-370` (bookmark limit)
- `product/tools/awedot/src/components/Panel.tsx:617-618` (session limit)
- `product/tools/awedot/src-tauri/src/lib.rs` (no license check in any Tauri command)

**Problem:** The Rust backend (`get_bookmarks`, `add_bookmark`, `get_sessions`, etc.) has zero license enforcement. Limits are purely UI-level slice operations on the React side. A user can:
- Open Tauri DevTools and mutate `license.status` in the Zustand store
- Call Tauri commands directly via the dev console
- Modify the bundled JS to remove the `isLimited` check

**Fix:** Add license status checks to at least one critical Rust command (e.g., `add_bookmark` should reject when free tier limit is exceeded). The local `license.json` cache is the source of truth for the Rust side — it can read the current status without network calls.

---

### P4 — Serverless rate limiting is per-instance, not per-IP

**File:** `product/tools/awedot-dev/api/verify.js:6-8`

**Problem:** `ipFailures` is an in-memory `Map`. Vercel serverless functions run across multiple isolated instances. An attacker can send failed verify requests to different instances, each resetting the counter, achieving an effective limit of `10 × instance_count` attempts per hour.

**Impact:** Brute-force attacks on license keys are feasible at scale. The 10-attempt window per hour is also generous for a targeted attack.

**Fix:** Use a distributed store (Vercel KV, Upstash Redis, or Supabase) for rate limit state. Alternatively, track failures directly in the `licenses` table with a `failed_attempts` counter and `last_failed_at` timestamp.

---

### P5 — Offline first trial start can reset trial via local file deletion

**File:** `product/tools/awedot/src-tauri/src/license/mod.rs:310-313`

**Problem:** When a user first starts offline, `start_trial()` does not write to the Keychain:

```rust
None => (chrono::Utc::now().to_rfc3339(), TRIAL_DAYS, TRIAL_DAYS as i32),
```

Attack path:
1. User starts app offline → gets 7-day trial (keychain has no `trial_sync`)
2. User deletes `~/.awedot/license.json`
3. User restarts app offline → gets another fresh 7-day trial (still no keychain watermark)
4. Repeat indefinitely

**Why the existing countermeasure doesn't help:** `offline_days_left()` reads from keychain `trial_sync`, which was never written during the offline-first start. The `max_elapsed` watermark only works *after* a successful server sync.

**Fix:** On any trial start (even offline), write a keychain watermark immediately. If the server has never confirmed this device, the watermark should reflect that uncertainty — e.g., set `max_elapsed = 0` and `days_left = TRIAL_DAYS` but record `synced_at` so subsequent offline starts know a trial was already claimed.

---

### P6 — awedot-admin CLI uses service_role key with no authentication

**File:** `product/tools/awedot-dev/bin/awedot-admin.js`

**Problem:** The admin CLI reads `SUPABASE_SERVICE_ROLE_KEY` from a local `.env.local` file. This key bypasses all Row Level Security and has full database access — it can generate, revoke, and list any license key. If the developer's machine is compromised, an attacker gains full license management access.

**Impact:** Developer workstation risk only — does not affect production users. Worth noting for the security model.

**Mitigation:** The `.env.local` is stored at `~/.config/awedot-dev/` (not in the project directory), which reduces accidental commit risk. Consider adding a confirmation prompt for destructive operations (`revoke`, `gen-batch`).

---

### P7 — License key format partially exposed in frontend regex

**File:** `product/tools/awedot/src/components/LicensePanel.tsx:84`

```ts
license.info.key.replace(/^(AWEDOT-\w+-\w+-)(\w+)-(\w+)$/, "$1****-****")
```

**Problem:** The regex `AWEDOT-\w+-\w+-` reveals the key prefix structure (3 segments + dash). Combined with `verify.js` doing `.toUpperCase()` and accepting any length `\w+`, an attacker can narrow brute-force guesses to the `AWEDOT-XXXX-XXXX-XXXX` format, reducing entropy per segment.

**Impact:** Low — brute-forcing a properly generated key (high-entropy random segments) is still computationally infeasible. But defense-in-depth would avoid leaking format hints.

**Fix:** Mask the entire key except the last 4 characters, regardless of format. Or better, don't return the full key to the client at all — only return a display name or truncated form from the verify endpoint.

---

## TODO Items

### Must fix before webhook goes live

- [ ] **P2 — Add LemonSqueezy webhook signature verification** (`api/webhook/lemonsqueezy.js`)
  - Implement HMAC-SHA256 on `X-Signature` header
  - Reject any request without valid signature before processing

### Must fix before wider distribution

- [ ] **P1 — Add device ownership check to deactivate endpoint** (`api/deactivate.js`)
  - Only allow deactivation from the bound device
  - Consider requiring a challenge-response signed by the Tauri app

- [ ] **P3 — Enforce free-tier limits in Rust backend** (`src-tauri/src/lib.rs`)
  - Add license status check to `add_bookmark` command
  - Read local `license.json` cache to determine tier without network call

- [ ] **P5 — Write keychain watermark on offline trial start** (`src-tauri/src/license/mod.rs`)
  - Even when server is unreachable, persist `trial_sync` to keychain on first trial creation

### Should fix soon

- [ ] **P4 — Replace in-memory rate limiter with distributed store** (`api/verify.js`)
  - Use Vercel KV or Supabase for cross-instance rate limit state
  - Consider lowering limit from 10 to 5 attempts per hour

### Nice to have

- [ ] **P6 — Add confirmation prompt for destructive admin commands** (`bin/awedot-admin.js`)
  - Warn before `revoke` and `gen-batch`

- [ ] **P7 — Don't expose key prefix format in frontend** (`src/components/LicensePanel.tsx`)
  - Mask full key, show only last 4 chars
