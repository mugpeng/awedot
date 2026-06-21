# License Device Migration — Edge Case

## 当前设计

1 key = 1 设备，可解绑后在其他设备重新激活。

正常流程：旧设备 → Deactivate → 新设备输入同一个 key → 激活成功。

## 边界问题：设备丢失或损坏

用户无法在旧设备上主动 deactivate，key 被锁死在已损坏的设备上。

**当前处理**：作者手动在 Supabase 将该 key 的 `status` 改回 `active`，清空 `activated_device_id`。用户量小时成本可控。

## 后续可选方案（量大时再做）

邮件自助解绑：激活时绑定邮箱，用户通过邮件链接自助重置绑定。需要邮件基础设施（Resend/Postmark）。
