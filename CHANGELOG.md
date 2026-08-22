# Changelog

## v0.7.5 — 2026-08-22

### Security

- Replaced unsigned in-app installer execution with a trusted GitHub Release handoff.
- Restricted external links to HTTPS on the official awedot and GitHub hosts.
- Open external links on Windows via `ShellExecuteW` instead of a `cmd /C start`
  shell-out, closing a command-injection path through URL metacharacters such as `&`.
- Hook configuration writes now keep `.awedot.bak` backups, preserve symlink-managed dotfiles,
  and replace real config targets atomically.

### Fixed

- Prevented stale bookmark-search responses from replacing newer results.
- Kept the shared mutation loading state active until all concurrent mutations finish.
- Avoided whole-store rollback snapshots overwriting unrelated concurrent changes.

### Changed

- Hooks are repaired when any detected provider/event is incomplete or after an awedot version
  change, instead of rewriting complete configurations on every launch.
- Rust formatting, strict Clippy, and tests now run automatically for backend pull requests.
- Development requires Node.js 20.19+ and the pinned Rust 1.95 toolchain.

## v0.7.4 — 2026-08-21

### Features

- **Windows in-app update**: downloads the NSIS installer and launches it directly from the app.
- **Windows host-app activation**: `activate_host_app` now starts/focuses GUI host apps on Windows.
- **Path basename display**: bookmarks and session rows show cleaner directory names via `pathBasename`.

### Fixed

- **Parent-process lookup in awedot-bridge**: switched to `current.parent()` so the bridge resolves the correct parent.
- **License cache path**: now respects `AWEDOT_LICENSE_CACHE` env override.
- **MutationObserver target in use-scroll-fade**: fixed observer attaching to the wrong node.
- **Root element validation**: `main.tsx` now validates `#root` exists instead of using a non-null assertion.

### Changed

- **Default terminal is platform-aware**: falls back to `wt` on Windows.
- **License module cleanup**: derived `PartialEq`, extracted `compute_offline_days_left`, and added comprehensive unit tests for cache/trial logic.
- **FloatingBall keys stabilized**: uses `DOT_STATES` for consistent React keys.
- **`recognize_terminal_app` marked unix-only** with a clarifying comment.
- **Removed unused `window_exists` wrapper** from the Windows platform layer.

## v0.7.3 — 2026-08-15

The multi-agent release: awedot goes from 2 tracked agents to 9 — OpenCode, ZCode, Cursor, Trae, and CodeBuddy join Claude Code and Codex — plus a ground-up pass on OpenCode session lifecycle reliability.

### Features

- **OpenCode support**: sessions are discovered from OpenCode's SQLite database with live process matching, show conversation previews like Claude/Codex, and resume via `opencode -s <id>`. Realtime events arrive through an OpenCode plugin that awedot installs and cleans up automatically. Sessions resumed with `-s` / `--session` are recognized and kept live even when the DB row is stale.
- **ZCode support**: SQLite discovery mirroring OpenCode, hooks written in ZCode's nested `events` shape, and host-app activation for jump/resume (GUI-first agent — no per-session resume). A live session silent for 30 minutes is downgraded to Idle so it can't stay "active" forever after a lost hook.
- **Cursor session support**: Cursor's hook vocabulary is normalized to awedot's, cursor-specific events are mapped, and resume activates the Cursor app.
- **Trae support**: Claude-shaped hooks in `~/.trae/hooks.json`; resume/jump activate the Trae app.
- **CodeBuddy support**: a Claude Code fork — same flat hooks shape, resume via `codebuddy --resume <id>`.
- **Hook-only terminal agents hide when they exit**: Gemini, Copilot, and CodeBuddy have no disk discovery, so a session whose process died (Ctrl+C, closed terminal) previously stayed Active until a 30-minute stale timeout. The bridge now captures the agent's pid; the session is marked Completed within seconds of the process dying.

### Fixed

- **Gemini/Copilot sessions were mislabeled as "agent"**: routing re-derived the provider from the payload's `source` field, which carries Claude semantics. Routing now uses the explicit awedot source tag.
- **Gemini/Cursor/Copilot bookmarks resumed with `claude --resume`**: each provider now uses its own CLI (`gemini --resume <id>`, `copilot --resume=<id>`) or activates its GUI app.
- **The OpenCode plugin never sent realtime events**: ESM `require()` threw on every event and the error was swallowed — no event ever reached awedot until this was bootstrapped properly.
- **Subagent sessions were tracked as top-level sessions** (OpenCode / ZCode): only main sessions (`parent_id` empty) are listed now.
- **Closed OpenCode sessions lingered for minutes**: OpenCode discovery matches processes by working directory, so a sibling `opencode` running in the same directory kept a closed session looking alive. A completed session is now revived only when discovery proves that exact session is running again — a fresh active DB row or an argv session-id match. Otherwise the tracking state disappears with the closed session, the same behavior Claude Code gets from its state file.
- **Ctrl+C'd OpenCode left a ghost session**: the in-process plugin dies with the agent and sends no farewell event, so nothing retired the session. OpenCode now gets the same pid-based retirement as Gemini/Copilot/CodeBuddy.
- **A live sibling's pid could keep a dead session alive**: for directory-matched providers the discovered pid may belong to a sibling session's process; replacing the session's own pid with it defeated the liveness check. Discovery now only fills a missing pid for these providers, never overwrites a captured one.

### Changed

- **Bookmarking is limited to CLI agents** (Claude Code, Codex, OpenCode): a bookmark promises "resume this exact session later", which GUI-first apps (ZCode, Cursor, Trae) can't honor — for those, jump-to-app is the whole story.
- **Platform support narrowed to macOS and Windows**: Linux fallback stubs and the generic "unsupported platform" code path are removed.

## v0.7.0 — 2026-08-12

The tray-icon release: awedot gains a macOS menu bar presence with a tray icon and quick actions, plus ball animation primitives that make the floating ball easier to reposition programmatically.

### Features

- **macOS tray icon**: awedot now appears in the menu bar with a template icon (macOS) and color icon (Windows). The tray menu exposes "Recenter" and "Quit"; left-click also recenters the ball.
- **Ball recenter from tray**: the floating ball listens for `tray://recenter` events and animates back to its default position, giving users an instant recovery path when the ball drifts off-screen.
- **Ball animation primitives**: `recenterBall()` and `animateBallTo()` are extracted into reusable helpers, making future programmatic movement straightforward.

### Changed

- **CI config**: macOS Rust job dropped; Windows build is now manual-only (triggered via Actions → CI → Run workflow).

## v0.6.5 — 2026-08-10

The licensing & purchase release: a full license lifecycle (trial → buy → activate → recover) lands, with multi-device support and a dedicated web pricing page.

### Features

- **License panel & activation**: the trial/license badge opens a panel showing the trial countdown, license activation (paste a key), the masked active key, and deactivate. Activation is enforced server-side — one device per key.
- **Multi-device licenses**: buy 1, 2, or 3 devices in a single purchase. Each device gets its own single-device key; all keys for a purchase are delivered together in one email and listed on the post-purchase page. A refund revokes every key in the purchase at once. Early-bird pricing: 1 device $9.98, 2 devices $16.98, 3 devices $23.98.
- **"Forgot your key?" recovery**: from the license panel, enter the purchase email and the linked key(s) are re-sent. The response is identical whether or not the email is known, so account existence isn't leaked. Rate-limited per IP (3/day).

### Changed

- **In-app purchase opens the web pricing page** (awedot.wehuman.top/pricing) in your browser. The page owns tier selection and creates the Creem checkout, so the desktop app no longer handles payment credentials directly — each tier's Buy button is wired to the checkout endpoint.
- **Backend licensing pipeline** (awedot-dev): the checkout → webhook → key-minting path was rebuilt for multi-device. Checkout carries the device count through Creem metadata; the webhook mints that many keys with count-based idempotency (a retried payment event never over-mints); the post-purchase success page and key-lookup endpoint return every key for a purchase.

### Fixed

- **Payments stopped auto-issuing keys**: three public edge functions (the Creem webhook, the recover endpoint, and the post-purchase page) had JWT verification enabled, but they're called without a Supabase JWT — by Creem's servers, by browser redirects, and by the app's HTTP client. Every payment callback was being rejected at the edge, so no license key was ever minted automatically. All public endpoints are now deployed with JWT verification off.
- **License key generation referenced a renamed column**: after a `checkout_id` rename, the key-generation RPC still inserted into the old `external_id` column (Postgres doesn't rewrite stored function bodies on a column rename), so minting failed silently. Consolidated to a single RPC overload that matches the current schema.

## v0.6.0 — 2026-08-01

### Fixed

- **Warp jump regressed for bookmarked sessions on macOS**: when `jump_to_session` was refactored to share code with Windows, the third parameter silently became the bookmark id (a 13-character string like `aweshelf_0001`) instead of the agent session id. Warp's window-title match needs a UUID with hyphens, so the title-matching step quietly no-op'd for any bookmarked session and either fell through to "activate the most recent Warp window" or returned "no actionable jump target" outright. Jump now takes `session_id` and `window_key` as separate arguments so each platform uses the one it actually needs. A regression test pins the difference.

### Changed

- **Platform layer extracted**: terminal integration (jump, resume, terminal detection) is now under `src-tauri/src/platform/{macos,windows,unsupported}/` and selected at compile time. macOS code is moved verbatim — no behavior change.
- **Hook transport split from event handling**: `sessions/socket.rs` no longer touches `tokio::net::UnixListener`. The `transport/` layer holds `unix_socket.rs` (macOS) and `named_pipe.rs` (Windows); `sessions/socket.rs` now only parses payloads and applies them to the registry. Wire format and dispatch are unchanged.

### Features

- **Windows (experimental)**: awedot now builds for Windows via `tauri build --runner cargo-xwin --target x86_64-pc-windows-msvc` (NSIS installer; MSI requires running on Windows). Windows Terminal + PowerShell is the only supported terminal. Each session launches into a named window (`awedot-<bookmarkId>`) so jump has a stable handle, since Windows Terminal exposes no way to focus a specific existing tab. Sessions the user started themselves are unreachable for jump — UI offers a "Reopen in new window" action that re-runs the bookmark to make it findable.

  **Windows build is currently in testing stage.** It has not been validated on a real Windows machine. Only Claude Code is fully functional. **Codex sessions all show as `Completed`** because Codex runtime discovery depends on `ps`/`lsof` (no Windows equivalent yet). The relevant TODO is `docs/todo/common-cfg-unix_0731.md` (items B and C). Tested by CI on `windows-latest` (Rust test suite: 119 passed).

## v0.5.4 — 2026-07-21

### Fixed

- **Warp resume silently failed**: prior approach simulated keystrokes via System Events, which requires Accessibility permission — an ad-hoc-signed build cannot reliably hold that permission, so the resume never reached Warp. Resume now writes a Warp Tab Config and opens it via `warp://tab_config/<name>`, which needs no special permissions.

### Changed

- **Warp resume opens a new tab in the active window** instead of a fresh window: switched from Warp Launch Config (`.yaml`, `warp://launch/`) to Warp Tab Config (`.toml`, `warp://tab_config/`), reusing the window the user was last working in
- **Resume confirmation wording**: backend and UI now say "Launched …" instead of "Resumed …" — launching a terminal is fire-and-forget, so a successful dispatch doesn't mean the session actually resumed
- **Warp config is overwritten, not deleted**: the transient `~/.warp/tab_configs/awedot-resume.toml` is left in place after each resume; the next resume overwrites it. The previous timed-delete could race and remove the file before Warp read it on cold start

## v0.5.3 — 2026-07-20

### Fixed

- **Trial registration retry**: on transient network failures, the app now attempts a best-effort registration for locally-tracked "ghost" devices, so trials that started offline sync as soon as the server is reachable
- **HTTP timeout**: `fetch_trial_status` timeout increased from 3s to 8s to reduce false negatives on slow networks

### Features

- **Download progress**: app updates now stream progress events from the Rust backend and display percentage / error state in the Settings UI

### Changed

- **Codex runtime refactored**: monolithic `codex.rs` split into `mod.rs`, `activity.rs`, `discover.rs`, `parse.rs`, `process_match.rs` for improved clarity and maintainability (behavior unchanged)

## v0.5.2 — 2026-06-24

### Fixed

- **Trial auto-registration**: `fetch_trial_status` now returns a three-state result (`Ok(Some)` / `Ok(None)` / `Err`) to distinguish "server reachable but device not in DB" from network failure
- **Offline trial preservation**: when a device that started its trial offline auto-registers, the original `trial_started_at` is sent to the server so the trial countdown is not reset to "now"
- **Edge function**: `trial-start` endpoint accepts optional `trial_started_at` from client for accurate offline trial registration

## v0.5.1 — 2026-06-22

### Features

- **Startup sound**: Island Welcome chime plays on app launch (C major ascending four-note with harmonic shimmer, 2.0s), respects notification mute setting

## v0.5.0 — 2026-06-21

- GitHub releases: https://github.com/mugpeng/awedot
- Website: https://awedot.wehuman.top/
- Community: https://github.com/mugpeng/awedot-community

### Features

- **One-command DMG build**: new `build:dmg` script compiles universal macOS binary and injects installer assets in a single step

### Changed

- DMG icon layout: `.DS_Store` written via Python for precise icon positioning — Installation Guide, awedot.app, Applications symlink, and Fix Gatekeeper command arranged at specified coordinates

### Fixed

- RTF filename renamed to `!Installation Guide.rtf` so it sorts before the app icon in Finder

## v0.4.9 — 2026-06-21

### Changed

- Remove `is_interrupt` dead code from state machine (was based on a non-existent Stop hook field)
- CI: add `cargo test` job on macOS to catch Rust compilation errors
- Fix build script: correct RTF filename from `README.rtf` to `Installation Guide.rtf`

## v0.4.8 — 2026-06-21

### Features

- **Ctrl+C interrupt handling**: state machine now treats Ctrl+C (is_interrupt=true) as Active → Idle transition, matching user expectation when cancelling a turn

### Changed

- **Version check migrated to GitHub API**: queries `/repos/mugpeng/awedot/releases/latest` instead of `awedot.vercel.app/api/version`
- Update fallback no longer hardcodes version string — returns null on error
- CI: add dev branch triggers, split into frontend and rust jobs
- Settings: add `auto_check_updates` default value

## v0.4.7 — 2026-06-21

### Features

- **Auto-replace app on update**: download DMG to /tmp, mount, copy over /Applications, relaunch — no manual drag-to-install needed

### Changed

- Simplify DMG injection: remove Python PIL background generation, inject `Installation Guide.rtf` alongside `Fix Gatekeeper.command`
- `Fix Gatekeeper.command` now points to `/Applications/awedot.app` instead of relative path

## v0.4.6 — 2026-06-20

### Features

- **Tauri commands for external links**: `open_url` and `download_and_open_update` commands replace browser `<a>` tags in LicensePanel, Panel, and SettingsView
- **Update download flow**: Download button with `downloadingUpdate` state feedback; DMG fetched from GitHub releases and opened automatically

### Changed

- `APP_URL` updated to GitHub releases latest page

## v0.4.5 — 2026-06-20

### Features

- **Software update check**: backend `check_for_updates` command queries `/api/version`; Settings toggle for auto-check (default on); update banner in panel header + Software Update section in settings
- **Hook event enrichment**: `PermissionRequest`, `Notification`, `SubagentStart/Stop` now carry `agent_id`, `title`, `notification_type` from hook payload
- **Session search enhanced**: search now includes `source_path` field

### Security

- **Trial anti-rollback**: `max_elapsed` watermark in TrialSyncData prevents clock-rollback from restoring trial days
- **Keychain trial guard**: deleting `license.json` can no longer reset trial countdown; Keychain is authoritative
- **Single-device binding**: default `device_limit` reduced from 3 to 1; enforced via `activated_device_id`

### Fixed

- License cache skips expired entries instead of returning stale data
- Verify API null-safe count check prevents false "already activated" errors
- Lipo output path corrected in `build-mac-universal.sh`
- Disabled webhook: removed unused imports and dead code

### Changed

- Removed unused fields from license cache schema: `tier`, `device_limit`, `cached_at`
- Supabase schema: `device_count` column removed, `device_limit` default changed to 1
- Renamed `loadLicense` to `initLicense` for clarity
- Universal macOS build: lipo creates sidecar binary directly in `src-tauri/bin/`

## v0.4.3 — 2026-06-19

### Features

- **Universal macOS build**: new `build:mac` script compiles for Apple Silicon and Intel, produces ad-hoc signed universal app
- **build:mac npm script** added to package.json for one-command universal macOS builds

### Security

- Dev license mode paths now gated behind `import.meta.env.DEV`, preventing production bypass of license checks

### Fixed

- `devLicenseMode` store action no-op in production builds; dev-only guard added to prevent accidental exposure

## v0.4.2 — 2026-06-19

### Features

- **Celebration fireworks**: burst from ball position on license activation; confetti animation on successful deactivation
- **English error messages**: license deactivation errors now in English for broader accessibility

### Fixed

- Confirm dialog now stays visible during deactivation loading state
- Deactivate status handling simplified to prevent UI flicker
- Biome lint issues resolved in fireworks refactor
- Canvas context type cast to satisfy Biome and TypeScript strictness

### Security

- Trial and license verification endpoints hardened against injection and race conditions
- Verify API race condition fixed; field scope reduced to minimum required

## v0.4.1 — 2026-06-18

### Features

- **License deactivation**: users can deactivate a device from LicensePanel, freeing the key for another device
- **Device binding enforcement**: verify API records `activated_device_id` and `activated_at`; deactivate endpoint validates ownership before clearing
- **Keychain-backed state**: device ID and trial sync data stored in system keychain (not plain files), preventing casual tampering
- **Trial escape vector analysis**: documented known bypass paths (keychain reset, client-side limit bypass) and mitigation options

## v0.4.0 — 2026-06-18

### Features

- **License system**: trial/free/activated states with server-managed trial (anti-clock-skew via server-computed days_left)
- **Device-bound trials**: `~/.awedot/device_id` UUID for hardware-bound trial enforcement
- **Vercel trial API**: `/api/trial/start` and `/api/trial/status` endpoints
- **LemonSqueezy license flow**: verify API marks key as `used` after activation; Supabase RLS policies updated
- **Fallback notifications**: resume rollback (aweswitch not found) emits yellow fallback toast via NotificationToast
- **License limit UI**: unified `LockedBlock` component for bookmarks and sessions; sort dropdown disabled for free tier
- **Dev mode switcher**: T/F/A buttons in PanelHeader (guarded by `import.meta.env.DEV`) for testing license states

### Fixed

- Terminal.app cold-start double-window bug: detect running state, reuse startup window
- Warp cold-start resume: longer delays (1.5s activate + 1.0s tab delay) when not running
- Fallback to raw provider command when aweswitch resume fails
- Panel collapses after successful resume and other operations

### Changed

- Store refactored: FallbackToast merged into NotificationToast as `type: "fallback"`
- `confirm_resume` returns `ConfirmResumeResult { is_rollback, message }` instead of plain string
- README badge: removed License badge

## v0.3.8 — 2026-06-18

### Features

- **Session search**: debounced client-side filtering by title, cwd, source, and more
- **Unified sort modes**: Status (default), Last Active, Provider, Project — for both bookmarks and sessions
- **Reusable SearchInput and SortDropdown components** extracted from Panel.tsx
- **Supabase license backend**: Vercel-deployed verify API and LemonSqueezy webhook for license key management
- **Multi-path terminal detection**: Warp and iTerm2 checked at `/Applications/` and `~/Applications/`

### Fixed

- Bookmark resume now correctly jumps to live sessions; dead sessions fall through to `confirmResume` which opens a new terminal
- Warp terminal resume uses longer AppleScript delays and `key code 36` for reliable Enter
- Panel collapses after successful resume, bookmark delete, and other operations
- Fallback terminal respects user's `default_terminal` setting (Warp / iTerm2 / Terminal.app)

### Changed

- Zustand store split into 5 domain slices (bookmarks, sessions, notifications, settings, ui) — 460 lines → 29-line composition root
- Sort labels renamed: "Recent" → "Date Added", "Activity" → "Last Active"
- Session status state machine refactored into dedicated `state_machine.rs` module

### Highlights

- Store architecture refactored for maintainability and testability
- Session discovery now includes real-time search and multi-dimensional sorting
- Terminal jump fallback uses user's preferred terminal instead of hardcoded Terminal.app
- License infrastructure laid out for LemonSqueezy and 荔枝数码 distribution

## v0.3.6 — 2026-06-18

### Changed

- Gate Cursor support behind `cursor` Cargo feature flag (disabled by default, enable with `--features cursor`)

## v0.3.5 — 2026-06-17

### Fixed

- Improved terminal detection via process tree walking — resolves correct terminal app even when env vars are missing
- Try precise TTY matching before app-specific jump logic, fixing cases where tab focus failed despite valid TTY
- Use full Terminal.app path in AppleScript to avoid ambiguity with Warp

### Changed

- Extract shared terminal detection (read_process_env, read_process_tty, normalize_tty, resolve_terminal_app_from_process_tree) into common module, eliminating duplication between Claude and Codex runtimes
- Unify bookmark-session linking with consistent priority: bookmark_id > active_session_id > provider+session_id
- linkBookmarkToSession now persists active_session_id to backend with optimistic update and rollback on error
- Codex non-live rollouts can now match running processes by working directory

## v0.3.1 — 2026-06-16

### Fixed

- Show "Save" button when linked bookmark has been deleted instead of stale "Saved" state
- Set correct initial window size (72px) matching BALL_SIZE on startup
- Precise floating ball centering on primary monitor via `primaryMonitor()` API
- Fix React effect dependencies for load* functions on mount

### Changed

- Lift `isBallOnLeft` state to shared store for single source of truth
- Window centers on primary screen before reading position on first launch
- Smart edge snapping: ball skips snapping to edges that have adjacent monitors
- Biome linter added with `lint`, `lint:fix`, `format` scripts

## v0.3.0 — 2026-06-15

Session profile management, multi-monitor support, explicit source routing, and bookmark lifecycle fixes.

### Features

- **Multi-monitor support**: Ball and panel clamp correctly on screens with non-zero or negative origins; all `window.screen` hardcoding replaced with Tauri monitor APIs
- **Smart edge snapping**: Ball skips snapping to edges that have adjacent monitors, preventing it from getting stuck between screens
- **Bookmark profile for Claude Code**: Profile field now available when bookmarking a Claude Code session (via confirm modal and inline edit form)
- **Profile gated to Claude Code**: Profile field only appears for Claude Code bookmarks/sessions — hidden for Codex and other providers
- **Codex jump support**: Codex sessions now use env-based terminal detection (same as Claude) for precise iTerm2/Warp/Terminal.app tab focusing
- **Explicit source routing**: Bridge accepts `--source <tool>` flag and injects `awedot_source` into hook payloads for deterministic routing instead of format guessing
- **Provider-namespaced bookmark keys**: Bookmarks use `provider:session_id` as key to avoid cross-provider collisions
- **New Codex hook events**: PermissionRequest, PermissionDenied, Notification, SubagentStart/Stop, PreCompact, StopFailure
- **Multi-dir hook detection**: `hooks_installed()` checks all tool config dirs (claude, codex, gemini, cursor, copilot)
- **Codex rollout enrichment**: Extracts `last_activity` and `summary` from event stream
- **Generic transition notifications**: Status transition detector emits success/failure notifications for any prior state
- **Drag state tracking**: `isBallDragging` store state suppresses toast window resizing during ball drag

### Bug Fixes

- Deleting a bookmark now clears `bookmark_id` on linked sessions, restoring the bookmark icon to unsaved state
- Codex jump falls back to TTY-based process tree detection when env vars are unavailable
- Toast container collapses width/margin to 0 when no toasts showing
- Toast window position extracted into shared `toast-window-position.ts` module
- Window shadow disabled on macOS for cleaner appearance

### Changed

- `isBallOnLeft` computed from actual monitor bounds instead of `window.screen.width`
- Version sync script (`scripts/sync-version.mjs`) keeps versions in sync across package.json, Cargo.toml, tauri.conf.json, and constants.ts

## v0.2.5

Toast animation fixes and floating ball stability improvements.

### Bug Fixes

- Fixed floating ball jumping when toast disappears — window position now adjusts to keep ball screen position fixed
- Fixed ball drifting right by 280px when toast disappears (incorrect TOAST_WIDTH offset)
- Prevent toast collapse drift with height locking and variable durations
- Ball hides immediately on panel expand, collapse follows panel position
- Render overlay ball during panel transitions for smooth visual continuity
- Smooth pulse end animation to prevent border artifacts
- Sync ball position after drag so toast direction updates correctly
- Eliminated toast ghost panel and pulse-ring border artifacts

## v0.2.2

Notification system hardening, toast content enrichment, and code cleanup.

### Features

- **Toast body content**: Toast notifications now show recent user input and AI output
- **Collapse animation**: Toast dismiss uses slide-out animation with staggered delays
- **Toast limit**: Cap at 3 visible toasts to avoid screen clutter

### Improvements

- Extracted `useToastWindow` and `useToastLifecycle` hooks from NotificationToast (399 → 217 lines)
- Removed duplicate `clearAllNotifications` call in use-panel.ts

### Bug Fixes

- Toast action button now correctly jumps to the session
- Add 500ms fallback timeout for missed transitionEnd events — toasts no longer get stuck on screen
- Call `AudioContext.resume()` to fix silent notification sounds in Tauri WebView
- Fixed floating ball position drift across expand/collapse cycles
- Ball collapses to saved center position, clamped to screen bounds
- Eliminated position race conditions in collapse animation
- Fixed toast clipping and ball-to-toast gap issues
- Prevented toast from overlapping the floating ball
- Aligned notification toast and ball glow with v3 design
- Toast expand uses rAF to sync with window resize
- Improved floating ball pulse lifecycle

## v0.2.1

Session expand levels, notification stacking, and icon redesign.

### Features

- **Three-level session expand**: Sessions now support collapsed → clamp-2 → full expand levels for better space management
- **Stacked notification queue**: Toast notifications now stack vertically with slide-in animations
- **Bookmark delete confirmation**: Added confirmation dialog when deleting bookmarks to prevent accidental deletions
- **Redesigned app icon**: New squircle shape with metallic border for a more polished look

### Bug Fixes

- Fixed drag behavior and rounded corners on the settings page
- Aligned ConfirmModal styling with BookmarkConfirmModal for visual consistency

## v0.2.0

State-aware notifications, five-ring floating ball, and polished session/bookmark UI.

### Features

- **Turn-level states**: Success and Failure states with five-ring floating ball layout, showing per-ring glow for each session
- **Session notifications**: Toast UI that appears when a session needs attention (waiting/success/failure), with distinct sound effects per state type
- **Mute toggle**: Settings option to silence notification sounds
- **Always-on-top**: Toggle to keep the panel window above others

### Improvements

- Softened panel edges with rounded corners and subtle shadow
- Polished list UI with improved spacing, fonts, and rounded card style
- Refined bookmark row with better profile display, trimming, and truncation
- Session row layout refactor with resume confirmation modal
- Streamlined bookmark detail view — removed redundant action bar, aligned card style with session row

### Bug Fixes

- StopFailure now correctly enters Failure state instead of generic Completed
- Notification toast skips window resize when panel is already open
- Restored dot number font size to 13/15px for five-ring layout
- Bookmark save sync, null guard, and dead code cleanup
- Reduced active stale timeout; Stop(false) no longer triggers state change

## v0.1.0

Initial release. AI session bookmark and tracking GUI built with Tauri 2 + React 19.

### Highlights

- Floating ball UI that lives on the screen edge, showing real-time agent status via glow dots
- Automatic discovery of Claude Code and Codex sessions from local transcript files
- Bookmark system with title, category, project path, and API profile support
- One-click resume that restores a session in the user's terminal with the original profile
- Cross-platform terminal launch (macOS Terminal.app, Windows Terminal, Linux fallbacks)
- Hook-based real-time session updates via Unix domain socket
- Session state machine with process liveness monitoring and automatic stale detection
- Admission rules to filter which sessions appear in the panel
- Draggable floating ball with edge snapping animation
- Resizable panel (width via side handles, height via bottom handle)
- Category-based bookmark filtering and full-text search
- Context menu on sessions for quick actions (resume, bookmark, copy ID)
- Keyboard-driven confirmation modals (Enter/Escape/y/n)
