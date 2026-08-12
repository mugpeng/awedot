# Rate Limit B — DB-backed limiter follow-up

**Created**: 2026-08-12
**Status**: Not started. Block on real evidence of distributed abuse.
**See also**: [`rate-limit-review.md`](./rate-limit-review.md) — predecessor
review of the per-function policies, kept as historical context.

## Why this file exists

A (in-process Map-based shared helper) shipped 2026-08-12 — see
`supabase/functions/_shared/ratelimit.ts`. The doc-comment in that file is
honest about its limits: each edge-function isolate has its own copy of
`buckets`, so counters do not survive a cold start and are not shared across
concurrent instances. That is fine for blocking script kiddies; it is NOT a
hard guarantee against a distributed attacker.

This file collects what a real follow-up looks like, so the work is one read
away when (and only when) it is justified.

## What B should do

Replace the in-process counter with a single source of truth that:

- is shared across every concurrent isolate of every function
- survives cold starts (counters are durable for at least the window length)
- self-resets when the window expires
- adds at most one DB round-trip per abuse-checked request

## Schema sketch

```sql
create table rate_limits (
  bucket       text        primary key,   -- "verify:<ip>", "recover:<ip>", "recover:email:<addr>"
  window_start timestamptz not null,
  count        int         not null default 0
);
-- index for the nightly cleanup:
create index rate_limits_window_start_idx on rate_limits (window_start);
```

`bucket` is the discriminator — function name + identity. The shared helper
takes a `bucket` prefix, callers add the identity; that way one table serves
every function without cross-talk.

## Atomic upsert (the one-round-trip trick)

```sql
insert into rate_limits (bucket, window_start, count)
values ($1, now(), 1)
on conflict (bucket) do update set
  count = case
    when rate_limits.window_start < now() - $2::interval
      then 1
    else rate_limits.count + 1
  end,
  window_start = case
    when rate_limits.window_start < now() - $2::interval
      then now()
    else rate_limits.window_start
  end
returning count;
```

`$2` is the window length (e.g. `'1 hour'`). The CASE inside `do update` is
the only fiddly bit — easy to get subtly wrong. The "first hit anchors a fixed
window" semantics match the in-process version closely enough; the only
behavioural delta is that the window is now anchored at the first DB write
after expiry, not at the first in-process hit, which is fine.

## The three patterns need three call shapes

| Pattern             | Helper returns                    | Used by                  |
|---------------------|-----------------------------------|--------------------------|
| Count every hit     | `over(bucket, limit) -> bool`     | trial-start, license-lookup, recover |
| Count only failures | `over(bucket, limit) + record(bucket)` on the failure path | verify |

`recover` is the most important function to wire up here — it spends real
Resend credits per request and is the only entry that emails an
attacker-chosen recipient, so it is also the natural place to add a SECOND
limiter keyed on `recover:email:<sanitized>` to stop distributed
email-bombing via the same inbox. That second key is the actual reason to
prioritise B over the others.

## Costs (the reason this is not done yet)

1. Hot-path write. Every anonymous request now costs a DB round-trip plus
   an insert/update. For verify and license-lookup (both called on the
   desktop app's hottest paths) this is the steepest part of the change.
2. Table growth. One row per unique identity, never deleted by the limiter
   itself. Need a cleanup job:
   ```sql
   -- nightly cron via pg_cron or supabase scheduled function
   delete from rate_limits where window_start < now() - interval '2 days';
   ```
   Multiple moving parts; new failure mode if the cron stops running.
3. Migration. The table is small but it is a new schema object — must be
   added to `supabase-setup.sql` and any backup/restore story reviewed.
4. Cost/value mismatch. We have no evidence of distributed abuse today.
   The current script-kiddie defence (A) is enough for the current threat
   model. B only earns its keep when we see real distributed traffic.

## When to do it

- Any of these signals: Resend bills climbing without matching legitimate
  signups; Supabase logs showing `verify` 429s from many distinct IPs in
  the same hour; a customer-report of email-bombing against a license
  buyer; manual review of `rate_limits` (if B is partially rolled out) or
  of abuse patterns in DB queries revealing a distributed source.
- Not before. Adding B "just in case" pays the hot-path tax for every
  request for an attack we have not seen.

## Alternative considered: edge / CDN rate limiting

Architecturally cleaner — Cloudflare rate-limit rules on
`awedot.wehuman.top/*/functions/v1/*` cost nothing per request and are
trivially distributed. Blocked by the fact that current production traffic
goes directly to `*.supabase.co/functions/v1/*`, which we do not front
with our own proxy. A future change to route all function calls through a
CF-fronted `awedot.wehuman.top/api/*` proxy would unlock this for free, and
would also be the right place to add caching, auth-jwt forwarding, and
request size limits. That is a separate, much larger piece of work and
should not be bundled with B.
