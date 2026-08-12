# Creem 销售渠道接入 — 进度与待办

> 最近更新：2026-08-07
> 仓库：后端 `awedot-dev`、桌面端 `awedot-source`、Supabase 项目 `bzaitdoemldsjjdeifeg`

## 背景与锁定决策

- **策略**：Creem 只做支付收银；密钥全部由我们自己生成，写入同一张 `licenses` 表（`source='creem'`）。桌面端 `verify`/激活/试用链路完全不动。
- **授权形态**：一次性买断**永久**（`expires_at=NULL`，与赠送密钥一致）；Creem 产品 `billing_type=one_time`；只处理 `checkout.completed` + `refund.created` 两个事件。
- **设备**：1 台（沿用现有 `verify` 单机绑定，零改动）。
- **密钥投递**：双通道——Resend 邮件 + 成功页轮询。成功页是主通道（付完款立即看到 key），邮件是兜底。
- **关联键**：`request_id`（checkout-create 生成）贯穿 success_url → webhook.`object.request_id` → `licenses.request_id` → 成功页轮询；`external_id`（=Creem checkout id `ch_...`）做幂等 + 退款反查。

## ✅ 已完成

### 代码（已写、已编译验证）
**后端 `awedot-dev`**
- `supabase-setup.sql`：`licenses` 加 `external_id`/`request_id` 列 + 唯一索引(幂等) + `generate_license_key()` 增 `p_source/p_external_id/p_request_id`（向后兼容）
- `supabase/functions/webhook-creem/index.ts` 🆕 验 `creem-signature`(HMAC-SHA256)；`checkout.completed` 幂等发永久 key + Resend 邮件；`refund.created`→revoked
- `supabase/functions/checkout-create/index.ts` 🆕 持 `CREEM_API_KEY`，建 Creem checkout，返回 `checkout_url`
- `supabase/functions/license-lookup/index.ts` 🆕 `GET ?rid=` 轮询取 key，限流+CORS
- `supabase/functions/success/index.ts` 🆕 内联 HTML 轮询页
- `supabase/functions/verify/index.ts`：加 `revoked`→410 分支
- `.env.local`：填入 Creem/Resend 配置
- 删除 `webhook-lemonsqueezy/` 死壳

**桌面端 `awedot-source`**
- `src-tauri/src/license/mod.rs`：`CHECKOUT_CREATE_URL` 常量 + `start_checkout` 命令 + `CheckoutCreateResponse` 结构体
- `src-tauri/src/lib.rs`：注册 `start_checkout`
- `src/components/LicensePanel.tsx`："Get a license" 按钮 → `invoke("start_checkout")` 打开 Creem 收银台，失败回退营销站

**验证**：`tsc --noEmit` 零错误 · `cargo check` 通过 · biome 无新增错误

### 部署（部分完成）
- ✅ SQL 已应用：`awedot-admin db supabase supabase-setup.sql` → "Migration applied successfully"
- ✅ Supabase secrets 已设置：6 个密钥（CREEM_API_KEY / CREEM_PRODUCT_ID / CREEM_WEBHOOK_SECRET / CREEM_MODE=test / RESEND_API_KEY / LICENSE_FROM_EMAIL）→ "count:6"
- ❌ **4 个边缘函数尚未 deploy**（见待办）

### 第三方配置
- ✅ Creem：产品 `prod_2pUdbsRd3E4LGeZhsOWzyg`（one_time，关闭 License Key Management）；webhook 已注册（`checkout.completed`+`refund.created`）
- ✅ Resend：`mail.wehuman.top` 的 DNS 已加（DKIM 在 `resend._domainkey.mail` ✅、return-path SPF 在 `send.mail` ✅，阿里云权威 NS 已生效）
- ⚠️ 注意：当前 `LICENSE_FROM_EMAIL` 还是 `license@wehuman.top`，**应改为 `license@mail.wehuman.top`**（见待办）

## 🔧 还需要做（按顺序）

### 1. Resend 域名验证（你操作）
- 去 [resend.com/domains](https://resend.com/domains) → `mail.wehuman.top` → 点 **"Verify DNS records"**。
- 绿了 → 继续；红了 → 看它标哪条：若提示 SPF，可能要把 SPF 也加到主机记录 `mail`（值同 `v=spf1 include:amazonses.com ~all`）。
- 验证通过后重跑自检，期望 HTTP 200：
  ```bash
  curl -X POST 'https://api.resend.com/emails' \
    -H 'Authorization: Bearer $RESEND_API_KEY' -H 'Content-Type: application/json' \
    -d '{"from":"awedot <license@mail.wehuman.top>","to":"license@mail.wehuman.top","subject":"t","html":"<p>t</p>"}'
  ```

### 2. 修正 LICENSE_FROM_EMAIL → `license@mail.wehuman.top`
- 改 `awedot-dev/.env.local`；重跑 secrets：
  ```bash
  TOKEN=$(grep '^SUPABASE_ACCESS_TOKEN=' ~/.config/awedot-dev/.env.local | cut -d= -f2-)
  SUPABASE_ACCESS_TOKEN="$TOKEN" supabase secrets set LICENSE_FROM_EMAIL=license@mail.wehuman.top --project-ref bzaitdoemldsjddeifeg
  ```

### 3. 部署 4 个边缘函数 ⚠️ 关键
- 这 4 个函数被 Creem / 浏览器 / Rust **公开调用，必须关掉 JWT 校验**（`--no-verify-jwt`），否则请求被 Supabase 拦成 401。
- 项目无 `config.toml`（现有 `verify`/`trial` 是公开的，说明都靠 deploy 时带 flag）。
  ```bash
  cd awedot-dev
  TOKEN=$(grep '^SUPABASE_ACCESS_TOKEN=' ~/.config/awedot-dev/.env.local | cut -d= -f2-)
  export SUPABASE_ACCESS_TOKEN="$TOKEN"
  supabase functions deploy checkout-create webhook-creem license-lookup success \
    --project-ref bzaitdoemldsjjdeifeg --no-verify-jwt
  ```

### 4. 端到端测试（Creem Test Mode）
- 用测试卡跑一笔 → 期望：
  - `awedot-admin db list keys` 出现 `source=creem`、`external_id=ch_...`、`request_id=...` 的永久 key
  - 邮件收到 key（域名验证后）
  - 浏览器落 `success?rid=...` 页轮询出同一 key
- 把 key 粘进 app LicensePanel → 激活成功（走现有 verify，单机绑定）
- 在 Creem 后台对该笔退款 → `refund.created` → 该 key `status=revoked`；app 再次 `verify` 返回 "License revoked"（410）
- 在 Creem 后台重发同一 `checkout.completed` → 不产生第二条 key（验证幂等）

### 5. 上线（切 production）
- Creem 关 Test Mode → 重取 prod 的 `CREEM_API_KEY` / `CREEM_WEBHOOK_SECRET` / 产品 `CREEM_PRODUCT_ID`
- `CREEM_MODE=prod`
- 重跑 `supabase secrets set` + 重新 deploy
- 在 Creem live 后台重新注册 **production** webhook endpoint（URL 同一个函数地址）

### 6. 代码提交
- `awedot-dev` 和 `awedot-source` 两个仓库的改动**均未 commit**（等端到端测试通过后再提交）。

## ⚠️ 需要在测试期确认的一个点

`request_id` 能否从 create-checkout 原样回到 webhook 的 `object.request_id`（成功页轮询链路的关键）。
- 若测试时 `licenses.request_id` 落库为 NULL（成功页轮不到、但邮件/激活正常）：在 `checkout-create` body 里再加一份 `metadata: { rid: <request_id> }`，webhook 改读 `object.request_id ?? object.metadata?.rid` 兜底。

## 环境值清单（值见 `awedot-dev/.env.local`，已 gitignore）

| 变量 | 说明 |
|---|---|
| `CREEM_API_KEY` | `creem_test_...`（test）；上线换 prod key |
| `CREEM_PRODUCT_ID` | `prod_2pUdbsRd3E4LGeZhsOWzyg` |
| `CREEM_WEBHOOK_SECRET` | `whsec_...`（test） |
| `CREEM_MODE` | `test` / `prod` |
| `RESEND_API_KEY` | `re_...`（注意：当前是"仅发送"权限，不能查域名状态） |
| `LICENSE_FROM_EMAIL` | 应为 `license@mail.wehuman.top`（待修） |

- Supabase 项目 ref：`bzaitdoemldsjddeifeg`
- webhook 函数 URL：`https://bzaitdoemldsjjdeifeg.supabase.co/functions/v1/webhook-creem`
