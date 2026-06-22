# 更新下载进度反馈

## 问题

点击 Download 更新后，按钮显示 "downloading..."，但没有任何进度反馈。网络慢或下载失败时，用户看到的是一个永远转圈的按钮，有卡死的错觉。

## 现状

- **前端** `src/store/ui.ts:115-124`：`downloadUpdate` 只有 `downloadingUpdate: boolean`，无进度、无错误展示
- **后端** `src-tauri/src/lib.rs:333-389`：`download_and_open_update` 一次性 `response.bytes()` 读完整个响应，300s 超时，无进度上报
- 前端的 `finally` 块在正常更新流程中不会执行（Rust 端 `exit(0)` 先杀进程），但网络错误时会走到，只是没展示错误信息

## 方案

1. **Rust 端**：用 `response.bytes_stream()` 逐块读取，每块通过 `app.emit("update-download-progress", { downloaded, total })` 推送进度
2. **前端**：监听 `update-download-progress` 事件，显示下载百分比
3. **错误展示**：`downloadUpdate` catch 错误后存入 state，在 UI 中显示具体错误信息（如 "下载超时"、"网络错误"）
4. **超时优化**：300s 对正常下载过长，考虑前端加一个 30s 后的"下载较慢，继续等待？"提示，或 Rust 端缩短超时

## 相关代码

- `src-tauri/src/lib.rs` — `download_and_open_update()`、`check_for_updates()`
- `src/store/ui.ts` — `downloadUpdate()`、`updateAvailable`、`downloadingUpdate`
- `src/components/SettingsView.tsx` — 更新按钮 UI
