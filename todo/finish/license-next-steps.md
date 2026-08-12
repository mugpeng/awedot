# License 恢复/Lifecycle 一轮工作之后 — 下一步

> 创建：2026-08-09
> 仓库：桌面端 `awedot-source`、后端 `awedot-dev`
> Supabase 项目 `bzaitdoemldsjjdeifeg`
> 背景：本轮做了 recover（忘了 key）UI + Rust 命令、`reissue`、生命周期重命名（unbind/revoke/restore）、`db list` 加列、`mode` 列 + 迁移、3 个边缘函数 redeploy、撤销 2 把测试 key。

## P0 — 验证今天的部署（先做，快）

- [ ] 做一次 Creem **测试购买**（app → Get a license → 测试卡付款）→ `awedot-admin db list keys` 应出现新行：`source='creem'`、`mode='test'`、带 `external_id`。
  - 验证 redeploy 后的 webhook → `generate_license_key(p_mode)` → `mode` 列链路真的通。
- [ ] 用那个购买邮箱跑一次 app 内 **"Forgot your key?"** → 确认收到重发邮件（recover 链路）。

## P1 — 把 awedot-source 的改动发布出去（最关键）

> 注意：recover UI（"Forgot your key?" + 可选中复制的帮助文案）和 Rust `recover_license` 命令**只在仓库里，用户已安装的版本还没有**。必须重新打包发布才到用户手里。

- [ ] bump `package.json` 版本号。
- [ ] `npm run sync-version`（同步 Cargo.toml / tauri.conf.json / constants.ts，见 awedot CLAUDE.md）。
- [ ] 本地完整测一遍（见下"发布前手测"）。
- [ ] `npm run build:mac` / `npm run build:dmg` 打包（universal）。
- [ ] 走 release（`awedot-release` skill）。
- [ ] git：`dev` 提交 → `main` 合并 → 回 `dev`。

### 发布前手测清单
- [ ] trial 正常倒计时。
- [ ] 激活一把 key（已激活态显示、masked key、deactivate 可用）。
- [ ] 未激活态点 **"Forgot your key?"** → 输邮箱 → 发送 → "Check your email" 已发送态。
- [ ] 不存在的邮箱 → 同样的确认文案（不泄露存在性）。
- [ ] 找回态点 **"No access to that email?"** → 展开帮助 → 鼠标可选中并复制 `peng@wehuman.top`。

## P2 — 收尾两个 license 缺口（已在 log/todo）

- [ ] **device-reset.md（lost-device 重置）**：刚加的 `awedot-admin db unbind <key>` 已能做 MVP-B（管理员协助重置：清设备绑定、key 回 `active`，新设备可激活）。剩下的只是 SOP——客服先核验购买邮箱 ownership 再 unbind。
  - 选项：直接归档到 `log/todo/archive/`（MVP 已由 `unbind` 覆盖）；或补一个"先校验 email 匹配再 unbind"的小封装命令 `db transfer <key> <email>`。
- [ ] **webhook-mint-fallback.md（`db mint`，付了钱但 webhook 漏发证）**：概率低，量起来或真遇到再建。设计已就绪。

## P3 — 小决定 / 清理

- [ ] **`mode` 列是否变行为开关**：prod 环境下 `verify` 拒绝 `mode='test'` 的 key？建议**保持纯标签**（测试 key 得能激活你才能测；上线后也不会再用 prod 的 test 模式发证）。如要强制力，在 `verify/index.ts` 加 mode 守卫。
- [ ] recover 帮助文案里的 `peng@wehuman.top` 确认是实际在收的支持邮箱。
