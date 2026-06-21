# Ctrl+C 打断 session 后状态仍显示 Active

## 问题

用户在 Claude Code 中 Ctrl+C 打断正在进行的 turn 后，awedot UI 中该 session 的状态仍然显示 `Active`（蓝色），而不是预期的 `Idle`。

## 根因分析

**Claude Code 的行为：**
- Ctrl+C 后，Claude Code 立即将 session 文件 (`~/.claude/sessions/<pid>.json`) 的 `status` 字段从 `"running"` 更新为 `"idle"`
- 但 **Stop hook 不会触发**（Ctrl+C 是终端层面的中断，turn 未完成，hook 系统不知道这个事件）
- Stop hook 只在 turn 正常结束时触发

**awedot 的状态驱动机制：**
- 状态主要由 hook 事件驱动（`hook_event_to_session_event` → `state_machine::decide_transition`）
- 磁盘发现（`process_monitor` 每 3 秒跑一次 `ReconcileFromDisk`）作为兜底
- 但 `claude.rs` 的 `discover()` 忽略了 session 文件的 `status` 字段，永远返回 `Idle`
- `should_keep_existing_status` 规则中 `(Active, Idle)` 阻止了 reconcile 把 Active 降级为 Idle

## 为什么不直接读 session 文件的 status 字段

尝试过让 `claude.rs` 读取 `status` 字段（`"running"` → Active，`"idle"` → Idle），但会破坏 `Success → Idle` 的 20 分钟降级窗口：

1. Turn 正常结束 → hook 设 Success → 文件变 `"idle"`
2. 3 秒内 reconcile 看到文件 `"idle"` → 尝试 Success → Idle
3. `(Success, Idle)` 规则本该拦住，但如果同时移除 `(Active, Idle)` 来修复 Ctrl+C，就会引入其他竞态问题

**核心矛盾：** `should_keep_existing_status` 只看 `SessionStatus` 枚举，无法区分「Ctrl+C 导致的 idle」和「正常结束导致的 idle」。

## 可能的解决方向

1. **在 Session 结构体中增加文件状态字段**：`discover()` 返回文件的原始 status（`file_status: Option<String>`），让 `merge_reconciled_session` 在 `(Active, Idle)` 场景下检查文件状态——如果文件从 `"running"` 变为 `"idle"`，说明是 Ctrl+C，允许降级；如果文件一直是 `"idle"`，说明是正常结束后的状态，保持 Success。

2. **在 discover() 中对比上次状态**：让 `discover()` 接收现有 registry 状态作为参数，对比文件 status 变化来推断 Ctrl+C。

3. **等 Claude Code 支持 interrupt hook**：如果未来 Claude Code 在 Ctrl+C 时触发一个专门的 hook（如 `PostToolUse` 带 `is_interrupt: true`），就可以从 hook 路径解决。

## 影响

- 低优先级：Ctrl+C 后窗口期很短（用户发下一条消息或退出 Claude Code 后状态立即纠正）
- 纯 UI 显示问题，不影响功能

## 相关代码

- `src-tauri/src/sessions/runtime/claude.rs` — `discover()` 函数
- `src-tauri/src/sessions/registry.rs` — `should_keep_existing_status()` 函数
- `src-tauri/src/sessions/process_monitor.rs` — `check_all_sessions()` 调用 reconcile
- `src-tauri/src/sessions/state_machine.rs` — 状态转换逻辑
