# Changelog

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
