# OpenCode 会话生命周期：已知边界（未做）

记录 v0.8.0 发布时明确接受、留待后续处理的三个边界。均已评估过影响，不阻塞发布。

## 1. 归档后会被 `-s` 残留 argv 复活

### 现象

在一个仍在运行的 `opencode -s <id>` TUI 里归档（archive）或删除该会话时，插件会发 `SessionEnd` → registry 置 Completed；但该进程的命令行里 `-s <id>` 仍然残留，发现路径的精确 argv 匹配会在下一个 3 秒周期把它复活成 Idle，直到用户退出该 TUI 进程。

### 根因

`-s` 匹配只看 argv，不知道会话在进程内部已被归档；而「Completed 只被精确匹配/Active 发现复活」的规则（`registry.rs::should_keep_existing_status`）无法区分「pid 检查杀掉的会话」（应允许复活）和「插件 SessionEnd 明确终结的会话」（不应复活）——两者共用 `is_session_ended` 标记。

### 可能方向

给 Session 增加「definitive end」语义（仅由插件 SessionEnd / session.deleted 设置，pid 检查退场不设置），复活规则对 definitive end 的条目一律不复活。

### 影响

窄场景、有界：进程退出即自愈。用户感知为「归档后会话在面板多停留一会儿」。

## 2. ZCode 未对齐本轮 OpenCode 修复

### 现象

ZCode 与 OpenCode 共享 DB-recency 合并规则（`status_is_db_recency_authoritative` 同时覆盖两者），但没有得到 `-s` argv 精确匹配和 pid 溯源语义：

- 闲置超过 `LIVE_GRACE_SECS`（300s）的会话从面板消失，即使 TUI 还开着；
- 从 bookmark resume 会重复开新终端，而不是 jump 到已打开的实例。

这正是 OpenCode 在 `docs/todo` 之外这几轮修掉的 bug 在 ZCode 上的原样保留。

### 未做的原因

ZCode CLI 的 resume 参数形式未验证（是否同样支持 `-s <id>` / `--session <id>`），不能直接照搬 `session_id_from_command`。

### 可能方向

确认 zcode-cli 的会话参数与数据目录后，把 `runtime/opencode` 的三件事移植到 `runtime/zcode`：argv 精确匹配（live 判定 + pid + jump target）、按 id 回查绕过 recency 窗口、cwd 匹配不携带 pid。发布前在支持矩阵（README「支持的 Agent」）注明 ZCode 当前体验弱于 OpenCode。

## 3. Windows 上 OpenCode DB 路径未验证

### 现象

`common.rs::opencode_db_path()` 在 Windows 上同样使用 `~/.local/share/opencode/opencode.db`（home 目录回退跨平台写死）。README 声称 macOS/Windows 支持 9 个 agent。若 Windows 版 OpenCode 的数据目录不是这个路径，发现路径会静默返回空——OpenCode 会话在 Windows 上完全不显示，且无任何报错。

### 未做的原因

没有 Windows 环境实测过 Windows 版 opencode 的实际数据目录。

### 可能方向

在 Windows 机器上运行 opencode 一次，确认数据目录；若不同，`opencode_db_path()` 按平台分支。顺带验证 Windows 的 `discover_opencode_processes`（sysinfo 路径）能否拿到含 `-s <id>` 的完整命令行。

## 相关代码

- `src-tauri/src/sessions/runtime/opencode/mod.rs` — `session_id_from_command` / `build_session`（精确匹配与 pid 溯源）
- `src-tauri/src/sessions/registry.rs` — `should_keep_existing_status` / `merge_reconciled_session`（复活与 pid 合并规则）
- `src-tauri/src/sessions/opencode_plugin.js` — `time.archived` / `session.deleted` → SessionEnd
- `src-tauri/src/sessions/runtime/common.rs` — `opencode_db_path` / `discover_opencode_processes`
