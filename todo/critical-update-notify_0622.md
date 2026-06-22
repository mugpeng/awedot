# Critical Update Always-Notify

用户关掉 "Check automatically" 后，仍然启动时检查更新，但只有关键/安全更新才弹横幅。

## 改动

### 1. Backend — `src-tauri/src/lib.rs`

- `check_for_updates` 返回 `Option<UpdateInfo>` 替代 `Option<String>`
- `UpdateInfo { version: String, critical: bool }`
- 解析 GitHub release body，包含 `[critical]` 或 `[security]` 则 `critical = true`

### 2. Frontend store — `src/store/ui.ts`

- 新增 `updateCritical: boolean` 状态
- `checkForUpdates` 解析新结构 `{ version, critical }`

### 3. Startup — `src/App.tsx`

- 去掉 `if (auto_check_updates)` 条件，无条件调用 `checkForUpdates()`

### 4. Banner — `src/components/Panel.tsx`

- 横幅条件改为：`updateAvailable && !updateBannerDismissed && (settings.auto_check_updates || updateCritical)`

## 标记方式

发布 GitHub Release 时在正文加 `[critical]` 或 `[security]` 即可。
