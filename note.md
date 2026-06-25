# Warp 关窗后 Session 延迟消失问题

## 现象

在 Warp 中运行 Claude session 后，直接关闭 Warp 窗口（非 Ctrl-C），awedot 前端的 session 列表不会立即更新，大约延迟 **30-60 秒**后 session 才变为 Completed 消失。Terminal.app 无此问题。

## 实测数据

session `8cbfdee9-39cf-4f98-a683-322477ee64fc`（PID 80948，TTY `/dev/ttys002`），关闭 Warp 窗口后立即采集：

| 检查项 | 关窗后立即 | ~1min 后 |
|--------|-----------|----------|
| PID 80948 存活（`kill -0`） | 是 | 否 |
| TTY `/dev/ttys002` 设备节点 | 存在 | 消失 |
| TTY write 探针（0 字节 write） | 返回 0（master 存活） | - |
| 状态文件 `~/.claude/sessions/80948.json` | 存在 | 消失 |

## 根因

**Warp 的终端关闭行为与 Terminal.app 不同：**

- **Terminal.app** 关窗时直接 `kill -9` 整个进程组，瞬间清理所有资源
- **Warp** 关窗时有一个 **~30-60 秒的宽限期**：pty master 不关闭，子进程不杀

在这段延迟期内，awedot 的三个检测信号全部报告"存活"：

1. `is_pid_alive()` → `true`（进程没死）
2. `discovered_ids.contains()` → `true`（状态文件还在）
3. `tty_alive()` 的 write 探针 → `true`（返回 0，master 没关）

代码逻辑本身正确——`tty_alive` 能检测 EIO，但 Warp 根本没关 master，所以 EIO 不会出现。

## awedot 现有防御（process_monitor.rs）

```rust
// Claude session 的存活判断：discovery AND tty_alive
let alive = discovered_ids.contains(&session_id) && tty_alive(tty.as_deref());
```

- `discovered_ids`：每 3 秒从 `~/.claude/sessions/*.json` 重新 discovery
- `tty_alive`：对 `/dev/ttysXXX` 做 0 字节 write，master 关闭后返回 EIO

两个信号都是对的，但都被 Warp 的宽限期"欺骗"了。

## 可能的 Workaround

| 方案 | 思路 | 代价 |
|------|------|------|
| 检测 Warp 是否还持有该 TTY | `lsof` 检查 Warp 进程是否还打开着该 ttysXXX；如果 Warp 已经不持有但子进程还在，提前标记 Completed | 每次检查要跑 lsof，性能开销 |
| 监听 Warp 窗口关闭事件 | Warp 是否有 API/通知机制暴露窗口生命周期 | 需要调研 Warp 是否支持 |
| 降低 `process_not_seen_count` 阈值 | 当前需要连续 2 次 not_seen 才标记 Completed（6 秒），但 Warp 宽限期 30-60 秒，帮不上忙 | 无效 |

## 结论

**根因是 Warp 的终端关闭行为**（延迟清理 pty master 和子进程），awedot 的检测逻辑本身没有 bug。如果要改善体验，需要针对 Warp 加一个绕过宽限期的额外信号。
