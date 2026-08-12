# Rate Limit Review — trial-start & verify

**Created**: 2026-08-11

## Current Config

### trial-start（`supabase/functions/trial-start/index.ts`）

```
3 次 / 小时 / IP
所有请求都计数（成功也计数）
存储：内存 Map（单实例，冷启动丢失）
```

**防什么**：批量创建试用账号，脚本循环 POST 不同 device_id 撑爆 trials 表。

**问题**：
- 阈值偏紧。一台机器 4 台设备同时开试用，第 4 台就被拦。
- NAT / 代理出口 IP 共享场景下会误伤多个真实用户。
- 纯内存 Map，实例重启后计数器清零，窗口不连续。

**结论**：3 次够用但偏紧。可提到 5 次/小时，或改为按 `device_id` 在数据库持久计数（trials 表已存 device_id，天然防重复）。

### verify（`supabase/functions/verify/index.ts`）

```
10 次失败 / 小时 / IP
仅验证失败时计数，成功不计
存储：内存 Map（单实例，冷启动丢失）
```

**防什么**：暴力探测 license key 是否存在。

**实际安全分析**：
- Key 空间：`AWEDOT-PRO-XXXX-XXXX-XXXX` = 12 hex chars = 48 bits ≈ 281 万亿种组合
- 即使不限流，10 次/小时的猜测速度穷举完需 281 万亿小时
- 所以限流主要防探测脚本，不是防穷举

**问题**：
- 10 次/小时较宽松，用户手误不会被拦。
- 代理池轮换 IP 可绕过（每个 IP 独立计数器）。

**结论**：10 次合理，可降到 5 次更保守。

## Summary

| | trial-start | verify |
|---|---|---|
| 目的 | 防批量滥用 | 防暴力探测 |
| 阈值 | 3次/小时（偏紧） | 10次失败/小时（合理） |
| 主要弱点 | IP误伤、内存不持久 | IP轮换可绕 |

## TODO

- [ ] trial-start：阈值提到 5 次/小时，或改为 device_id 持久计数
- [ ] verify：考虑降到 5 次失败/小时
- [ ] 长期：两个都改为数据库/Redis 持久限流，避免多实例和冷启动问题
