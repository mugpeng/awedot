# Cursor 磁盘发现 + Copilot Hook 事件补全

## Context

awedot 支持 5 种 agent，但只有 Claude 和 Codex 有完整的运行时磁盘发现。Cursor 和 Copilot 仅依赖 hook 事件推送——app 重启后历史 session 丢失。

**目标**：给 Cursor 加磁盘扫描（参照 Codex 模式），补全 Copilot/Cursor/Gemini 共用的 `parse_agent_hook` 缺失的 4 种事件。

---

## Part 1: Copilot Hook 事件补全

### 1a. `hooks.rs` — 扩展 `AgentHookPayload`

添加 5 个 `Option` 字段：
```rust
pub title: Option<String>,
pub message: Option<String>,
pub notification_type: Option<String>,
pub error: Option<String>,
pub error_details: Option<String>,
```

### 1b. `hooks.rs` — `parse_agent_hook()` 补 4 个 match arm

| normalized name | HookEvent | 额外数据来源 |
|---|---|---|
| `notification` | `Notification` | `title`, `message`(fallback `last_assistant_message`), `notification_type` |
| `stop_failure` | `StopFailure` | `error`, `error_details` |
| `jump_target_updated` | `JumpTargetUpdated` | `HookCommon` 的 terminal 字段 |
| `pre_compact` | `PreCompact` | 仅 `session_id` |

### 1c. 测试

为每个新增 match arm 写测试，覆盖 PascalCase 和 snake_case 两种命名。

---

## Part 2: Cursor 运行时磁盘发现

### 2a. `common.rs` — 添加 `cursor_sessions_dir()`

```rust
const CURSOR_SESSIONS_DIR_ENV: &str = "AWEDOT_CURSOR_DIR";
pub fn cursor_sessions_dir() -> PathBuf {
    resolve_base_dir(CURSOR_SESSIONS_DIR_ENV, &[".cursor", "projects"])
}
```

### 2b. 新建 `runtime/cursor.rs`

**数据结构：**
- `TranscriptCandidate` — path, session_uuid, project_dir_name, modified_at
- `CursorSnapshot` — initial_prompt, last_user_text, last_assistant_message, tool_name, tool_input_preview

**核心函数：**

1. `discover(bookmark_map) -> Vec<Session>`
   - 扫描 `~/.cursor/projects/*/agent-transcripts/*/*.jsonl`
   - 跳过纯数字目录（timestamp dirs）和 `empty-window`
   - 过滤 24h 内的文件，cap 40 个，按 mtime 排序

2. `discover_transcript_candidates(base_dir) -> Vec<TranscriptCandidate>`
   - 三层目录遍历：`{project_dir}/agent-transcripts/{uuid}/{uuid}.jsonl`
   - 从目录名提取 UUID

3. `decode_project_path(encoded) -> String`
   - `format!("/{}", encoded.replace('-', "/"))`
   - `"Users-peng-Desktop-Project"` → `"/Users/peng/Desktop/Project"`

4. `stream_transcript_for_activity(path) -> CursorSnapshot`
   - 读前 10 行提取 `initial_prompt`
   - 读尾 200 行提取 `last_user_text`, `last_assistant_message`, tool info
   - Cursor JSONL 格式：`{"role":"user","message":{"content":[{"type":"text","text":"..."}]}}`
   - assistant 的 `tool_use` blocks 提取 tool_name + input preview

5. `build_session_from_transcript(candidate, bookmark_map) -> Session`
   - cwd = decode_project_path
   - status: mtime < 5min → Active, 否则 → Idle（无 PID）
   - pid = None, is_process_alive = false
   - bookmark_key("cursor", uuid)
   - 调用 `metadata::apply_display_fields()`

**关键设计：**
- 无 PID，活动检测靠文件 mtime（5 分钟阈值）
- `metadata::extract()` 不直接使用（Cursor JSONL 无 title/cwd 字段），自行解析
- 大文件效率：前 10 行 + 尾 200 行

### 2c. `runtime/mod.rs` — 注册 cursor 模块

```rust
mod cursor;
// in discover_sessions():
sessions.extend(cursor::discover(bookmark_map));
```

### 2d. `metadata.rs` — display title 补全

`compute_display_title` 的 source match 补上：
```rust
"cursor" => "Cursor",
"copilot" => "Copilot",
"gemini" => "Gemini",
```

---

## 实施顺序

1. hooks.rs — AgentHookPayload 扩展 + parse_agent_hook 补全 + 测试
2. common.rs — cursor_sessions_dir()
3. cursor.rs — 完整模块 + 测试
4. runtime/mod.rs — 注册
5. metadata.rs — display title 补全

## 涉及文件

| 文件 | 操作 |
|---|---|
| `src-tauri/src/sessions/hooks.rs` | 修改 |
| `src-tauri/src/sessions/runtime/common.rs` | 修改 |
| `src-tauri/src/sessions/runtime/cursor.rs` | 新建 |
| `src-tauri/src/sessions/runtime/mod.rs` | 修改 |
| `src-tauri/src/sessions/metadata.rs` | 修改 |

## 验证

- `cargo test` 通过所有新增和现有测试
- `cargo build` 编译无错误
- 手动验证：启动 app，Cursor session 在 UI 中正确显示（source="cursor"，标题、cwd、activity 状态正确）
- Copilot hook 事件：构造 Notification/StopFailure/JumpTargetUpdated/PreCompact payload 确认解析正确

---

## 进度

- [x] Task 1: Expand AgentHookPayload and add missing event handlers in hooks.rs
- [x] Task 2: Add cursor_sessions_dir() helper to common.rs
- [x] Task 3: Create runtime/cursor.rs module for Cursor disk discovery
- [ ] Task 4: Register cursor module in runtime/mod.rs and update metadata.rs
- [ ] Task 5: Run tests and verify compilation

**当前状态**：已在 `feature/cursor-copilot-full-support` 分支完成 Task 1-3，需要完成 Task 4-5 后合并到 main。
