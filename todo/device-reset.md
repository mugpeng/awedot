# 设备重置 / 转移（lost-device）— 设计与待办

> 创建：2026-08-09
> 仓库：后端 `awedot-dev`、桌面端 `awedot-source`、静态站 `awedot-web`
> Supabase 项目 `bzaitdoemldsjjdeifeg` · 表 `licenses`

## 背景与问题

授权模型是**单机绑定**：key 第一次 `verify` 成功时，`licenses.status` 从 `active` → `used`，并写入 `activated_device_id`（见 `verify/index.ts`）。

正常转移已经覆盖：app 内「Deactivate this device」→ `deactivate` 边缘函数清掉当前设备绑定 → key 回到 `active` → 新设备可激活。

**缺口**：买家**弄丢/报废了已绑定的设备**，无法在那台设备上跑 deactivate → key 卡在 `used` + 旧 device_id → 新设备 `verify` 返回 **409 already activated** → 被锁死。和「找回 key」是两个不同问题（找回 key 已由 `recover` 函数解决；这里解决的是「有 key 但绑死在丢失的设备上」）。

> 注意：退款 `refund.created` → `status=revoked`（已实现）。重置是**保留授权、只挪设备**，与退款互斥。

## 锁定决策

- 重置 = 把某条 license 的绑定清掉：`status → active`、`activated_device_id → null`、`activated_at → null`。
- **重置会踢掉旧设备**（旧设备下次 `verify` 失效）。这是预期行为——是 owner 在转移设备。
- 触发门槛必须证明 ownership：**知道 key + 控制购买邮箱**，二者都要。

## 方案

### A. 自助：邮箱确认重置（目标态，volume 起来再做）
1. 买家在 app 或 web 输入 key + 购买邮箱。
2. 后端校验 key 与 email 匹配同一条 license → 生成一次性 token（短期、单次）→ 发确认邮件。
3. 买家点邮件链接 → 确认页（**必须托管在 awedot-web，Supabase 不能渲染 HTML**）→ 点确认 → 重置绑定。
4. 买家在新设备激活。
- 优点：完全自助、可扩展。代价：要建 token（无状态 JWT 或 licenses 加 `reset_token`/`reset_token_expires_at` 列）、要在 awedot-web 建确认页。

### B. 客服协助重置（推荐 MVP，先上）
- 买家回复购买邮件说明情况。管理员用 `awedot-admin` 跑一条重置命令（按 key，先核验邮箱 ownership）。
- 优点：最简、最安全、零新基建。代价：人工、不可扩展。
- 早期量小，先 B；量起来再做 A。

### C. app 内凭 key 直接重置（不推荐单独用）
- 输 key → 校验邮箱匹配 → 立即重置，无邮件确认。比 A 少一步，但 key 一旦泄露就能被重置踢人，不建议。

## 推荐

**先 B（客服协助，MVP），设计上预留 A。** 复用现有 `licenses` 列，无需改 schema；A 落地时再加 `reset_token` / `reset_count`（审计+防滥用）。

## 实现步骤（MVP = B）

### 后端 `awedot-dev`
- 新增边缘函数 `reset-device`（`--no-verify-jwt`）：
  - 入参：`{ key, email }`；校验 `licenses` 里 `key` 匹配且 `user_email` 匹配且 `status != revoked`。
  - 执行重置：`UPDATE licenses SET status='active', activated_device_id=null, activated_at=null WHERE key=$1 AND user_email=$2`，带 `status='used'` 守卫防并发。
  - 默认**只允许管理员调用**（MVP）：加一个 admin secret 头校验（`x-admin-secret` ↔ secret），不对公众开放自助。A 阶段再去掉 admin gate、改邮件确认。
  - 限流 + 记日志（key、email、IP、时间）。

### 管理端 `awedot-admin`
- 加子命令 `awedot-admin license reset <key>`：调 `reset-device`，带 admin secret。先校验该 key 的 `user_email` 与请求方邮箱一致（ownership 核验留给人）。

### 审计（可选，A 阶段需要）
- `licenses` 加 `reset_count int default 0`、`last_reset_at timestamptz`；每次重置自增。用于看异常频繁重置。

## 安全 / 风险

- 重置踢掉旧设备：只有 owner 应触发。B 阶段靠人工核验邮箱；A 阶段靠 key+email+邮件确认三重。
- 限流：按 key 和按 email 双维度（防爆破/骚扰）。
- 日志：所有重置留痕，便于事后排查。
- 与退款隔离：`status='revoked'` 的 key 拒绝重置。

## 待确认

- `awedot-admin` 当前是否已有 license 子命令的脚手架（`db list keys` 提到过）？reset 命令挂哪。
- admin secret 放哪（Supabase secret `RESET_ADMIN_SECRET`）。
- A 阶段的 token 用无状态 JWT 还是 DB 列——倾向 JWT（零 schema 改动），但 JWT 撤销难；DB 列更可控。
