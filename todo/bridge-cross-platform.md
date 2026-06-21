# Bridge 跨平台 + Release Workflow

当前 bridge 只有 aarch64-apple-darwin，需要支持全平台。

## 背景

- Bridge 是 147 行的 Rust 二进制，负责把 Claude Code 等 agent 的 hook payload 通过 Unix socket 转发给 awedot 主进程
- 当前用了 `std::os::unix::net::UnixStream`（Unix-only）
- Server 端用了 `tokio::net::UnixListener`（Unix-only）
- CI 只跑 lint/typecheck/test，没有构建步骤

## 方案：用 `interprocess` crate

`interprocess` 提供跨平台 local socket API：Unix 上是 domain socket，Windows 上是 named pipe。

### Cargo.toml

```toml
interprocess = { version = "2", features = ["tokio"] }
```

### Bridge 端 (`src-tauri/src/bin/awedot-bridge.rs`)

- `std::os::unix::net::UnixStream` → `interprocess::local_socket::LocalSocketStream`
- `socket_path()` → `socket_name()`，按平台返回不同格式：
  - Unix: `/tmp/awedot-hooks.sock`
  - Windows: `awedot-hooks`（named pipe 名）
- 其余逻辑不变（stdin 读取、inject_metadata、写入）

### Server 端 (`src-tauri/src/sessions/socket.rs`)

- `tokio::net::UnixListener` → `interprocess::local_socket::tokio::LocalSocketListener`
- `tokio::net::UnixStream` → `interprocess::local_socket::tokio::LocalSocketStream`
- `default_socket_path()` → `default_socket_name()`，同上平台逻辑
- 删掉 `std::fs::remove_file` — Windows named pipe 自动清理，Unix 上 `LocalSocketListener::bind` 自己处理

### 平台 socket 命名

```rust
fn socket_name() -> Cow<'static, str> {
    #[cfg(windows)]
    { "awedot-hooks".into() }
    #[cfg(not(windows))]
    {
        let dir = env::var("XDG_RUNTIME_DIR")
            .ok()
            .or_else(|| env::var("TMPDIR").ok())
            .unwrap_or_else(|| "/tmp".to_string());
        format!("{}/awedot-hooks.sock", dir).into()
    }
}
```

## 构建目标

| 目标 | 平台 |
|------|------|
| aarch64-apple-darwin | macOS ARM（当前已有） |
| x86_64-apple-darwin | macOS Intel |
| x86_64-unknown-linux-gnu | Linux x64 |
| aarch64-unknown-linux-gnu | Linux ARM |
| x86_64-pc-windows-msvc | Windows |

## Release Workflow

新建 `.github/workflows/release.yml`：
- 触发：tag push (`v*`)
- 矩阵构建：5 个目标平台
- 每个 runner 上：`cargo build --bin awedot-bridge --release` + `npm run tauri build`
- 产物上传为 GitHub Release assets

## 验证

1. `cargo test` — bridge 的 `inject_metadata` 测试通过
2. `cargo build --target <triple> --bin awedot-bridge` — 各平台交叉编译成功
3. macOS 上 `tauri dev` — hooks 正常收发
4. Windows 上手动测试 named pipe 连通性
