# Trial Escape Vectors

Known ways a user can bypass the trial without purchasing a license key.

---

## 1. Keychain Reset (medium friction, most practical)

**Steps:** Delete `~/.awedot/` → open Keychain Access.app → delete the `awedot` service entries (`device_id`, `trial_sync`) → restart app.

**Why it works:** Device identity is a UUID stored in Keychain. Clearing it causes a new UUID to be generated on next launch, which the server treats as a brand-new device and grants a fresh 7-day trial.

**Fix options:**
- Bind device_id to a hardware fingerprint (e.g., IOPlatformExpertDevice serial) so regenerating Keychain still yields the same ID.
- Require a server-side email/account to start trial — the account becomes the identity, not the UUID.

---

## 2. Client-Side Limit Bypass (high friction, technical users)

**Steps:** Open Tauri WebView DevTools → modify the Zustand `license.status` value in memory.

**Why it works:** All feature limits (session count, bookmark count) are enforced purely in frontend JS (Panel.tsx). The Rust backend has no license check; it serves session and bookmark data unconditionally.

**Fix options:**
- Move at least one hard limit to the Rust layer (e.g., cap the number of sessions returned by `get_sessions` based on license state read from local cache).
- Accept the risk — this requires developer tooling and is not a casual bypass.
