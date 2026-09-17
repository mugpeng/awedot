<div align="center">
  <img src="logo/logo.png" alt="awedot" width="180">
  <h1>awedot: AI Session Bookmark Manager for AI Agents <a href="https://github.com/wehuman01/aweskill"><img src="https://raw.githubusercontent.com/wehuman01/aweskill/main/logo/aweskill-badge2.svg" alt="aweskill companion"></a></h1>
  <p><strong>A floating orb lives at your screen edge. One-click bookmark the current session, resume anytime with the original API profile.</strong></p>
  <p>
    <a href="./README.zh-CN.md">简体中文</a> ·
    <a href="https://awedot.wehuman.top/">Website</a> ·
    <a href="#community">Community</a>
  </p>
  <p>
    <a href="https://github.com/mugpeng/awedot"><img src="https://img.shields.io/github/stars/mugpeng/awedot?style=flat-square" alt="Stars"></a>
    <a href="https://github.com/mugpeng/awedot/releases"><img src="https://img.shields.io/github/v/release/mugpeng/awedot?style=flat-square" alt="Version"></a>
    <a href="./LICENSE"><img src="https://img.shields.io/badge/license-proprietary-7C3AED?style=flat-square" alt="License"></a>
    <a href="https://github.com/mugpeng/awedot"><img src="https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20(in%20development)-0078D4?style=flat-square" alt="macOS available; Windows in development"></a>
  </p>
</div>

## Features

| Feature | Description |
|---|---|
| Session bookmarks | One-click save of the current AI session, restore anytime |
| Categorized management | Organize bookmarks by project/category, find them fast |
| Real-time discovery | Automatically scans local sessions of Claude Code, Codex, and other agents |
| One-click resume | Restore the session in a terminal, carrying the API profile from that moment |
| SSH Remote | Monitor AI coding agent sessions on remote servers |
| Floating orb form | Lightweight and always available, never takes workspace, click to expand |
| Native desktop app | macOS (shipped); Windows in development (no Linux support) |

## Download

See [Releases](https://github.com/mugpeng/awedot/releases) for the latest `.dmg`.

> After mounting, open `/Volumes/awedot/Installation Guide.rtf` for step-by-step instructions if macOS blocks the app from launching.

## Changelog

See [CHANGELOG.md](https://github.com/mugpeng/awedot/blob/main/CHANGELOG.md).

## How to Use

1. **Install**: Download the `.dmg` and drag `awedot.app` into Applications. If macOS warns "developer cannot be verified", double-click the `Fix Gatekeeper` script in the same folder.

2. **Floating Orb**: After launch, a glowing orb sits at your screen edge, showing real-time status of your AI agent.

3. **Open Panel**: Click the orb or press the hotkey to expand the panel. Browse **Sessions** (active AI coding sessions) and **Bookmarks** (saved sessions).

4. **Bookmark**: Click the bookmark icon on any session to save it with a title, category, project path, and API profile.

5. **Resume**: Click any bookmark or session to restore it in your terminal — with the original API profile and terminal settings intact.

6. **Search & Filter**: Full-text search, sort by status / time / tool / project, and filter by category.

7. **SSH Remote**: Open Settings → Remote Servers, add a server (name / host / user) and click Deploy. Remote agent sessions then appear live in the panel, tagged with the server name.

## Platform Support

| Platform | Resume terminal | Jump (locate the terminal hosting a session) |
|---|---|---|
| macOS | Terminal.app (osascript) | Supported |
| Windows (in development) | Windows Terminal (`wt`), falls back to PowerShell | Only windows launched by awedot itself |

> Linux is not supported: the platform layer keeps only macOS / Windows implementations, has no
> Linux build stubs, and ships no installers. The core session tracking (hooks + disk discovery)
> is cross-platform in theory, but no promise is made.

## Supported Agents

"Discovery" means awedot can rebuild the session list straight from disk after start/restart; agents marked "real-time only" reappear after the next event once awedot restarts. The "real-time events" column is where the in-app "install hooks" step writes; all support one-click install and orphan self-cleanup.

| Agent | Session discovery | Real-time events | Resume command |
|---|---|---|---|
| Claude Code | `~/.claude/sessions/*.json` | `~/.claude/settings.json` | `claude --resume <id>` |
| Codex | rollout JSONL + process matching | `~/.codex/hooks.json` | `codex resume <id>` |
| OpenCode | SQLite (`opencode.db`) + process matching | `~/.config/opencode/plugins/awedot.js` (plugin) | `opencode -s <id>` |
| ZCode | SQLite (`db.sqlite`) + process matching | `~/.zcode/cli/config.json` (nested `hooks.events`) | activate the ZCode app |
| Cursor | transcripts directory | `~/.cursor/hooks.json` | activate the Cursor app |
| Gemini CLI | Real-time only | `~/.gemini/settings.json` | `gemini --resume <id>` |
| Copilot | Real-time only | `~/.copilot/settings.json` | `copilot --resume=<id>` |
| Trae | Real-time only | `~/.trae/hooks.json` | activate the Trae app |
| CodeBuddy | Real-time only | `~/.codebuddy/settings.json` | `codebuddy --resume <id>` |

Notes:

- **GUI-first agents (ZCode / Cursor / Trae)**: the CLI only launches the GUI; there is no
  per-session resume. Bookmark "Resume" and "Jump" merely bring the app to the foreground
  without locating the specific session.
- **Claude-compatible family (CodeBuddy / Trae / Gemini / Copilot)**: hooks configuration and
  payload format reuse Claude's flat shape, so integration cost is low; adding a similar agent
  usually takes one install path plus one routing branch.
- **Subagents**: OpenCode / ZCode track only main sessions (empty `parent_id`); subagents are
  not listed separately.
- **When sessions disappear (OpenCode / ZCode)**: when the process exits, or the session's own
  DB row goes silent for more than 5 minutes, it is marked finished and hidden from the list
  (sibling sessions in the same directory cannot keep it "alive"); the next message brings it
  back automatically. The trade-off: during a silent tool call longer than 5 minutes the
  session disappears temporarily and returns when the call finishes.
- **When sessions disappear (Gemini / Copilot / CodeBuddy)**: the hook carries the agent
  process pid; about 6 seconds after the process exits (including Ctrl+C or closing the
  terminal) the session is marked finished and hidden. Trae is excluded from this mechanism
  (its hooks fire from a short-lived launcher process; sampling the pid would kill live
  sessions by mistake).
- OpenCode / ZCode SQLite access is read-only (safe under WAL concurrency) and does not affect
  the agent.
- awedot repairs hooks only on first install, when hooks are missing, or when the app version
  changes. Before modifying a JSON config it keeps a `.awedot.bak` backup in the same
  directory and replaces the file atomically to avoid corrupting it mid-write.

## Software Updates

awedot checks the official GitHub Release for new versions. When an update is detected, the app
opens the corresponding official Release page for the user to download and install through the
system. Until the release pipeline produces Tauri-signed artifacts, the app will not download
or execute installers in the background without signature verification.

## SSH Remote

Run CLI coding agents (Claude Code, Codex, Gemini CLI, Copilot, OpenCode, Trae, CodeBuddy, …)
on a remote server over SSH and the sessions show up live in the awedot panel, tagged with the
server name, unified with local sessions.

### How it works

```
[Remote server]                                       [Local machine]
agent hooks → awedot-bridge (static Linux musl) → ssh -R tunnel → localhost TCP listener → the same session pipeline
```

- **Deploy**: fill in name/host/user under Settings → Remote Servers and click Deploy. awedot
  auto-detects the remote architecture (Linux x86_64/aarch64), uploads the ~2MB static bridge
  binary to the remote `~/.awedot/bin/`, installs hooks for the same agents as the local install (agents missing on
  the server are skipped; only adding or touching awedot's own entries, never other tools'
  configs), and establishes the reverse tunnel.
- **Tunnel**: rides your own system `ssh` (`~/.ssh/config`, ProxyJump, MFA, and agent
  authentication all work as usual). Reconnects automatically with exponential backoff;
  tunnels are restored on app restart.
- **Privacy**: the bridge forwards hook events only (status and summaries) and never reads
  code files; events travel back through your own SSH tunnel, not via any third party.
- **Uninstall**: deleting a server runs `remove-hooks` automatically and removes the remote
  binary, leaving nothing behind.

### Prerequisites

- `ssh` on the local machine (bundled with macOS/Linux; Windows needs the OpenSSH client).
- Remote Linux bridge binaries: download `awedot-bridge-linux-{amd64,arm64}` from a
  [Release](https://github.com/mugpeng/awedot/releases) into `~/.awedot/bin/`
  (build from source — see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)).

### Known limitations (stated honestly)

- Remote session liveness relies on hook events (SessionEnd) and stale timeouts; after an app
  restart, remote sessions reappear on the next event (new prompt / tool call).
- Jump for a remote session opens an `ssh -t` terminal landing in the session's working
  directory (when known) and cannot focus the exact remote pane.
- Remote sessions cannot be bookmarked or resumed — their transcripts live on the server, so a
  local save/resume could never reach them. The Save action is hidden for remote sessions.
- Remote approval is UI state only (same as local) and is not written back to the agent.

## Community

**Report a Bug** — [Open a Bug Report](https://github.com/mugpeng/awedot/issues/new?template=bug_report.yml)

**Request a Feature** — [Open a Feature Request](https://github.com/mugpeng/awedot/issues/new?template=feature_request.yml)

**Ask a Question** — [Open an Issue](https://github.com/mugpeng/awedot/issues/new)

## Awesome Ecosystem

awedot is part of a growing family of "awesome" tools built around AI coding agents — local-first, agent-operable, and fun to use.

### CLI Tools

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI-first skill package manager supporting 47+ AI coding agents.
- **[aweswitch](https://github.com/wehuman01/aweswitch)** — Agent profile switcher for Claude Code, Codex, and OpenCode.
- **[awerouter](https://github.com/wehuman01/awerouter)** — Smart router that splits requests between Flash and Pro models using structural signals, cutting unnecessary model spend.
- **[aweshelf](https://github.com/wehuman01/aweshelf)** — Bookmark, categorize, and restore AI coding sessions; pairs with aweswitch to save profiles and launch with one command.
- **[aweshare](https://github.com/wehuman01/aweshare)** — Share local Ollama/vLLM backends, domestic coding plans, or authorized OpenAI/Anthropic subscriptions through a self-hosted hub — a sharing economy for tokens.
- **[awewarm](https://github.com/wehuman01/awewarm)** — Subscription window warmer that keeps AI coding-plan windows active, for local setups and through a remote hub server.
- **[awescholar](https://github.com/wehuman01/awescholar)** — AI-agent-operable scientific literature discovery and curation.

### Desktop Apps

- **[awedot](https://awedot.wehuman.top/)** — A floating orb at your screen edge keeps track of the current AI session: bookmark it in one click, resume anytime, and pair with aweswitch to pin the agent's config (e.g., relaunch with the GLM model).

### Project Collections

- **[Awesome AI Meets Biology](https://github.com/Webioinfo01/Awesome-AI-Meets-Biology)** — A curated survey of AI applications in biology, bioinformatics, and biomedical research. Powered by awescholar.
- **[Awesome AI Virtual Tumor](https://github.com/Webioinfo01/Awesome-AI-Virtual-Tumor)** — A curated collection of state-of-the-art AI systems for virtual tumor modeling and simulation: static models, dynamic models, agents, benchmarks, and reviews.

## Support

If awedot saves you time, consider supporting it:

- ⭐ Star the repo — it helps others find it.
- ☕ [Ko-fi](https://ko-fi.com/mugpeng) — buy me a coffee.
- 💬 WeChat — scan the QR code below.

<p align="center">
  <img src="assets/images/wechat-pay.jpg" alt="WeChat Pay" width="240">
</p>

> Sponsors keep this project maintained — thank you.


## License

awedot is proprietary software — see the [License](./LICENSE). The trial, activation, and
purchase flows inside the app govern the product experience and services offered by the
official distribution build.
