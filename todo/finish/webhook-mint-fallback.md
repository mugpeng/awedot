# 付款成功但 webhook 漏发证（paid-but-no-key）— 设计与待办

> 创建：2026-08-09
> 仓库：后端 `awedot-dev`
> Supabase 项目 `bzaitdoemldsjjdeifeg` · 表 `licenses` · webhook `webhook-creem`

## 背景与问题

购买流程依赖 `webhook-creem` 收到 Creem 的 `checkout.completed` 后，调 `generate_license_key` 在 Supabase **生成** key（source='creem'、external_id=checkout_id）。Creem 在这个流程里只是支付通道，不管 key。

正常链路：付款 → Creem 发 `checkout.completed` → webhook 发证 → `success` 页轮询 `license-lookup` 显示 key + Resend 发邮件。

**缺口**：webhook 发证这步**持续失败**（webhook 自身报错、Supabase 短暂不可用、RPC 失败且 Creem 重试耗尽……）→ 买家付了钱，但 `licenses` 表里**根本没有这条记录**。

后果：
- `success` 页永远显示 "pending"（`license-lookup` 查不到）。
- `db reissue` 救不了——reissue 是改一条**已存在**记录的邮箱，这里压根没记录。
- 买家付了钱拿不到 key，是最硬的客服事故。

> 注：webhook 发证失败时返回 500，Creem 会按 30s/1m/5m/1h 重试，所以"持续失败"概率低。但一旦发生，目前无兜底。

## 与相邻能力的边界

- `recover`：解决「有 key、忘了 key」（邮箱对）。
- `reissue`：解决「有记录、邮箱打错」（按 external_id 改邮箱 + 重发）。
- **本 todo**：解决「**没记录**、付了钱」——webhook 漏发，需要手动补发。

## 方案

### A. 管理端手动补发（推荐 MVP）
- 新增 `awedot-admin db mint <checkout_id> <email> [--mode test|prod]`：
  - 直接调 `generate_license_key(p_source='creem', p_external_id=checkout_id, p_email=email, p_mode=...)` 生成 key。
  - **幂等**：靠 `external_id` 上的 unique index（`idx_licenses_external_id`）——若 webhook 后来补发成功或重复执行，第二次会撞 unique 约束失败，不会双发。（实现时捕获 23505，提示"已存在"。）
  - 客服在 Creem dashboard 用卡末四位/交易号找到订单 → 拿 checkout_id → 跑 mint。
- 优点：复用现有发证 RPC、零新基建、幂等。代价：人工。

### B. 自动兜底 + 告警
- webhook 发证失败到第 N 次重试仍失败 → 触发告警（邮件/日志 metric），让人立刻介入。
- 可选：定时 job 扫 Creem 近 N 天已完成的 checkout，与 `licenses.external_id` 对账，缺失的自动补发。
- 优点：覆盖无感知漏发。代价：要建对账/告警，复杂度高。

## 推荐

**先 A（手动 mint，MVP），量起来再考虑 B 的对账告警。** A 几乎零成本（一个 CLI 子命令 + 幂等处理），且直接闭环"付了钱没 key"。

## 实现步骤（MVP = A）

### 管理端 `awedot-admin`（`awedot-dev/src/commands/db.js`）
- 加 `case "mint"`：
  - 入参 `<checkout_id> <email> [--mode test|prod]`（mode 默认按当前 CREEM_MODE 或留空）。
  - 调 `db.rpc("generate_license_key", { p_email, p_source:'creem', p_external_id: checkout_id, p_mode })`。
  - 捕获 unique 冲突（`error.code==='23505'`）→ 提示该 checkout_id 已发证，建议用 `db list`/`reissue` 处理。
  - 成功后可顺带触发 `recover` 重发邮件（复用 `resendKey`），或直接打印 key 让客服转交。

### 可选告警（B 的一部分）
- `webhook-creem`：发证失败时，除返回 500 让 Creem 重试外，累计失败次数超阈值则发一封告警邮件（复用 Resend）。

## 安全 / 风险

- mint 必须只由管理员触发（CLI 已是 admin-only，靠 service role key）。
- 幂等靠 external_id unique index，杜绝双发/重复激活。
- mode 要标对（test/prod），否则污染 test/prod 统计（见 licenses.mode 列）。
- 与退款隔离：若该 checkout 已 refund，不应补发（mint 前可先查 Creem 订单状态，或人工判断）。

## 待确认

- mint 成功后是否自动重发邮件，还是只打印 key 由客服手动转交（量小建议后者，更可控）。
- 是否需要 B 的对账 job（取决于实际漏发频率，先观察）。
