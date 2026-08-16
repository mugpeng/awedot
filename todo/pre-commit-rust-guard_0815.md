# Rust 代码门禁 + lib.rs 结构整理

**Created**: 2026-08-15
**Status**: Not started

## 1. Pre-commit / Pre-push Rust 门禁

**优先级**: 高（成本最小的防回归手段）

### 背景

当前本地与 CI 对 Rust 代码均无自动门禁：

- `scripts/pre-commit.sh` 只跑 Biome（--staged）+ tsc，**不碰任何 Rust 代码**。
- `ci.yml` 只在 ubuntu 上跑前端（私库计费顾虑），dev 推送不被验证——注释里明说
  "Day-to-day work is UNVERIFIED by CI"。
- `rust-ci.yml`（windows-latest）是手动触发的 workflow_dispatch。

已发生的实际事故：v0.7.x 给 bridge 加 `agent_pid` 时，Windows 分支写出了
`proc.parent()`（应为 `current.parent()`）的编译错误，因为没有任何自动路径编译
Windows 目标，一直溜到 2026-08-15 手动 `cargo xwin check` 才发现。期间的
v0.7.x Windows 二进制整体不可构建，hook-only agent（Gemini/Copilot/CodeBuddy）
的进程死亡检测也随之失效。

### 方案

1. **pre-commit**（`scripts/pre-commit.sh`）追加：

    ```sh
    echo "🦀 Rust check..."
    cargo check --manifest-path src-tauri/Cargo.toml --features cursor
    ```

   增量编译秒级，不构成提交负担。

2. **pre-push** 新增 `.git/hooks/pre-push` 安装：xwin 增量约 40s，放 pre-commit
   偏重，放 push 前合适：

    ```sh
    cargo xwin check --manifest-path src-tauri/Cargo.toml \
      --target x86_64-pc-windows-msvc --features cursor
    ```

   需要同步改 `package.json` 的 `prepare` 脚本：目前只拷贝 pre-commit.sh，要加一份
   pre-push 的拷贝（脚本本体放 `scripts/pre-push.sh`）。

3. 前置条件写入脚本注释：`rustup target add x86_64-pc-windows-msvc` +
   `cargo install cargo-xwin`；缺工具时脚本应跳过并提示，而不是卡死 push。

### 范围外（另行决策，不在本 todo）

- 在 CI 上恢复 Rust 验证：私库计费是已记录的顾虑；若放到公共仓库
  mugpeng/awedot（公共仓库 Actions 免费）则属于 release 自动化那一摊。

### 验收

1. 故意在某个 `#[cfg(windows)]` 函数里写错变量名 → pre-push 能拦截。
2. 正常提交/推送耗时无明显劣化（pre-commit +几秒，pre-push +约 40s）。
3. 未装 xwin 的机器上 push 不被卡死，打印跳过提示。

---

## 2. 拆分 lib.rs 更新流程到 update.rs

**优先级**: 中（结构性改善，纯机械搬移，低风险）

### 背景

`src-tauri/src/lib.rs` 约 719 行、27 个 Tauri command 横跨六个域，靠分节注释
维持秩序。其中最大的一块非 command 逻辑是应用内更新流程（约 150 行）：

- `check_for_updates` command + `is_version_newer`
- `download_and_open_update` 的 macOS / Windows 两个 `#[cfg]` 变体
- （mac：下载 DMG → 挂载 → 替换 /Applications → 重启；win：下载 NSIS 安装包 →
  启动安装器）
- 共享的 `download_with_progress`（带进度事件流）

2026-08-15 的 Windows 对齐又往里加了 Windows 变体和共享下载函数，入口文件在
持续变胖。这是 code-zen 评估中 lib.rs 巨文件问题里最值得先拆的一片。

### 方案

新建 `src-tauri/src/update.rs`，整体搬移上述四块，`lib.rs` 里
`generate_handler!` 的引用改为 `update::check_for_updates` /
`update::download_and_open_update`。纯机械搬移，不改任何行为。

搬移时顺手保持现状：

- 两个平台变体的 `#[cfg]` 结构不动
- `download_with_progress` 的 `update-download-progress` 事件名不动
  （前端 `ui.ts` 在监听）

### 明确不做（防止过度发挥）

- **不**把 27 个 command 按域全拆（bookmark/session/settings/admission…）。
  它们是薄编排层，有分节注释，全拆 churn 大于收益。
- **不**借机改更新行为（URL、进度事件、安装策略）。

### 验收

1. `cargo check --features cursor` 与
   `cargo xwin check --target x86_64-pc-windows-msvc --features cursor` 零警告。
2. `cargo test --features cursor` 全过（191+2）。
3. `git diff` 审查确认只有搬移，无逻辑改动。
