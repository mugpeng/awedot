# awedot SSH Remote（对标 Vibe Island SSH Remote）

## 目标

在远程服务器上经 SSH 运行 Claude Code / Codex，session 实时出现在 awedot 面板中（带服务器标签），监控/通知体验与本地一致。首批 agent：Claude Code + Codex；远程系统：Linux（x86_64 / aarch64，musl 静态二进制零依赖）。设置里填 host/user 点 Deploy 全自动完成部署。

## 架构：复用现有事件管线

现有本地链路：agent hooks → `awedot-bridge` → Unix socket（行分隔 JSON）→ `handle_line` → registry → 前端。

远程链路只需替换传输段，两端逻辑全部复用：

```
[远程服务器]                                    [本机]
agent hooks → awedot-bridge (Linux musl)  →  ssh -R 隧道  →  localhost TCP listener
                                                  ↓ 注入 awedot_host 标签
                                            handle_line（现有解析/准入/registry）→ UI
```

用系统 `ssh` 子进程建隧道（`ssh -N -R`），不引入 russh：`~/.ssh/config`、ProxyJump、MFA、agent 转发全部白得，且和 Vibe Island 一样"经用户自己的 SSH 隧道回传"。

## 实施步骤

### 1. Bridge 支持远程模式 + 安装子命令（`src-tauri/src/bin/awedot-bridge.rs`）
- 加 `--endpoint <host:port>` 参数：改为 TCP 连接（默认仍走本地 Unix socket/named pipe，行为不变）。
- 加 `install-hooks --source <claude|codex>` 子命令：在远程本机执行与本地相同的 hook 配置合并。做法：把 `hooks_config.rs` 中纯配置合并逻辑抽成可复用函数（bin 通过 `awedot_lib::` 引用，模块改 pub），单一事实来源；只装 Claude（`~/.claude/settings.json`）和 Codex 的 hook。
- Fail-open 原则保持：任何错误静默退出，绝不阻塞 agent。

### 2. App 侧 TCP transport + 会话标签
- 新增 `src-tauri/src/transport/tcp.rs`：仅监听 127.0.0.1，行分隔 JSON 协议与 Unix socket 完全一致；每台服务器一个独立本地端口（自动分配，用户无需配端口）。
- 收到 payload 后先注入 `awedot_host: <server-name>` 再进 `handle_line`——标签由 App 按连接归属盖章，远程不可伪造。
- `Session` 增加 `host: Option<String>`（None=本地）；registry 键改为 `"{server}/{session_id}"` 防远程/本地 ID 撞车，展示 ID 不变。
- 进程存活监控跳过远程 session（本机无 pid），依赖 SessionEnd + 现有 stale 超时。
- 明确限制：远程 session 不做磁盘 reconcile——App 重启后远程 session 在下一次 hook 事件（下一条 prompt/工具调用）时重新出现。

### 3. SSH 隧道管理（新模块 `src-tauri/src/remote/`）
- 服务器配置 `{ name, host, user, port }` 持久化到 `~/.config/awedot/remote-servers.json`。
- 每台服务器 spawn `ssh -N -o ExitOnForwardFailure=yes -R <port>:127.0.0.1:<local-port> user@host`；supervisor 监控进程退出，指数退避+抖动重连（1s→60s 封顶），网络切换/休眠唤醒后自动恢复；App 启动时自动恢复已配置的隧道。
- 远程端口优先用 `-R 0:` 让 ssh 自动分配（解析 stderr 的分配端口），失败回退到 17300–17399 区间探测。
- 状态事件 `remote-status-updated`（connecting/connected/disconnected + 错误信息）推给前端；ssh 不存在、认证失败等如实显示。

### 4. 全自动 Deploy（`remote/deploy.rs`）
1. `ssh user@host uname -sm` 探测远程架构；
2. 上传对应的 musl 静态 bridge 二进制到 `~/.awedot/bin/awedot-bridge` 并 chmod +x（经 `ssh 'cat > …'` 流式写入）；
3. 远程执行 `awedot-bridge install-hooks --source claude` 与 `--source codex`（只增改 awedot 自己的 hook 条目，保留用户已有配置，与本地安装器同一套合并逻辑）；
4. 建立隧道。Uninstall 反向执行：移除 hook 条目 + 删二进制。
- 二进制来源：Tauri resources 打包 `awedot-bridge-linux-amd64/arm64`，CI 用 `cross` 或 musl target 交叉编译。

### 5. Tauri 命令 + 前端
- 命令：`list_remote_servers` / `add_remote_server`（deploy+连隧道）/ `remove_remote_server` / `get_remote_server_status`。
- SettingsView 新增 "Remote Servers" 区：添加表单（name/host/user/port）、Deploy 进度（探测→上传→安装→连接）、状态指示灯、删除。
- SessionRow 在 provider 旁显示服务器徽标；远程 session 的 Jump 改为打开终端执行 `ssh -t user@host`（如实标注：无法精确聚焦远程某个 pane）。远程 Resume 列为后续项，不在本次。
- `src/types`、store 同步更新。

### 6. 测试
- Rust 单测：payload 盖章、registry 按 host 键控、ssh 参数拼装、deploy 脚本生成（不真连 ssh）。
- 阶段 2 可脱离 ssh 本地自测：`awedot-bridge --endpoint 127.0.0.1:<port>` 直连 TCP listener 验证全链路。
- 前端 vitest 覆盖新组件；最终对一台真实 Linux 服务器手工验收。

## 明确不做（本次范围外）
- 远程审批回写（本地审批目前也只是 UI 状态，无回写通道，保持一致）。
- OpenCode/ZCode 远程（SQLite 扫描 + 插件安装路径另做）。
- FreeBSD 远程、嵌入式 ssh 库（russh）。

## 实施顺序
1 → 2 → 3 → 4 → 5 → 6（1、2 完成后即可本地验证远程链路的核心，再叠加 ssh 自动化）
