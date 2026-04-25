# MOBILE_APP_SPECS_V3_TBD.md — Backend, Upload Pipeline, & Deployment

> **Status: TBD.** This document is a working draft for the work that backfills every "Backend dependency" line in `MOBILE_APP_SPECS_V2.md`. It assumes v1 capture and v2 UI are shipped. Numbers (timeouts, page sizes, retention windows) are starting points open to negotiation with the platform team — flagged with `// tunable`.
>
> Companion docs: `MOBILE_APP_SPECS_V1.md` (capture engine, immutable), `MOBILE_APP_SPECS_V2.md` (UI layer).

---

## 1. Goals

1. Replace every fixture in v2 with a real API.
2. Move recording transfer from "share sheet to a laptop" → "background upload to Cloudflare R2 with resumable, chunked, network-aware retry."
3. Stand up the review console + points settlement pipeline (separate web app — not in scope here, but contracts are).
4. Make the whole stack deployable from a single CI workflow on Cloudflare + a managed Postgres.
5. Don't break v2 widgets — only swap repository implementations.

## 2. Architecture

```
┌──────────────┐     HTTPS/JSON      ┌──────────────────────┐
│  Mobile App  │ ──────────────────► │  api.digients.dev    │ Cloudflare Workers
│ (Flutter v2) │ ◄────────────────── │  (Hono on Workers)   │ + D1 / Hyperdrive→Postgres
└──────┬───────┘                     └─────────┬────────────┘
       │                                       │
       │  presigned PUT (multipart)            │ writes
       │  R2 multipart upload API              ▼
       ▼                                ┌─────────────────┐
┌──────────────┐                        │ Postgres (Neon) │
│  R2 bucket   │ ◄──── manifest ───────►│ users, tasks,   │
│  digients-   │                        │ submissions,    │
│  recordings  │                        │ points_ledger   │
└──────┬───────┘                        └─────────────────┘
       │
       │  R2 event notification → Queue
       ▼
┌──────────────────┐    ┌──────────────────┐
│ Cloudflare Queue │ ─► │ GPU runners      │  HaWoR + depth
│ (process_upload) │    │ (Modal / Runpod) │  pipeline
└──────────────────┘    └──────────────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │ Review Console   │  (separate app, web)
                        │ web.digients.dev │
                        └──────────────────┘
```

**Why these picks:**
- Cloudflare Workers + R2: zero egress fees, the upload path is already adjacent to the storage; D1/Hyperdrive simplifies the data tier.
- Postgres on Neon: real relational store for users, tasks, ledger; D1 is fine for caching but row-level constraints + transactions matter for points.
- Queues: decouple "upload finished" from "GPU processing." We can rate-limit GPU spend without dropping uploads.

## 3. API Surface (`api.digients.dev`)

All endpoints JSON; auth via short-lived JWT (15 min) + refresh token (30 d). All times ISO 8601 UTC. Errors follow RFC 7807.

### 3.1 Auth

| Method | Path | Notes |
|---|---|---|
| `POST` | `/v1/auth/start` | Body: `{ phone | email }`. Sends OTP. v3.1: SMS via Twilio fallback per region. |
| `POST` | `/v1/auth/verify` | Body: `{ identifier, code }`. Returns `{ accessToken, refreshToken, profile }`. If the user is new, server creates the account on first verify (no separate `/register`). |
| `POST` | `/v1/auth/oauth/apple` | Body: `{ identityToken, nonce }`. Validates against Apple JWKS, returns same shape as `/verify`. |
| `POST` | `/v1/auth/oauth/google` | Body: `{ idToken }`. Validates against Google JWKS, returns same shape as `/verify`. |
| `POST` | `/v1/auth/refresh` | Returns new pair. |
| `POST` | `/v1/auth/logout` | Revokes refresh. |

UID format: `DGT-{8-char base32}`. Mocked in v2 mockup as `DGT-A47K3PX9`.

**v2 mockup behavior (placeholder).** The AuthScreen in v2 accepts any input (or none) and routes straight to Home with no backend call. This is intentional — auth is fully gated behind v3. v2 is single-user, local-only; Hive boxes are unscoped. When v3 lands, each box gets keyed by `userId` and existing local recordings are attached to whatever account the user signs in as on first launch (one-time migration prompt).

**Token storage.** `accessToken` in memory only; `refreshToken` in iOS Keychain / Android Keystore. Never in Hive — Hive is unencrypted on Android by default.

### 3.2 Tasks

| Method | Path | Notes |
|---|---|---|
| `GET` | `/v1/categories` | Returns `[{ id, name, glyph, openCount, comingSoon, avgReward }]`. Cacheable 60s. Drives Home masonry. |
| `GET` | `/v1/tasks?category=&filter=&cursor=&limit=20` | `filter ∈ {high_reward, quick, beginner, verified}`. Cursor pagination. |
| `GET` | `/v1/tasks/:taskId` | Full detail — title, publisher, points, duration, lighting, surface, steps[], demoVideoUrl, slotsLeft, deadline. |
| `POST` | `/v1/tasks/:taskId/reserve` | Locks a slot for 30 min. Returns `reservationId`. Required before recording — UI calls this when user taps Record. // tunable |
| `DELETE` | `/v1/tasks/reservations/:id` | Releases lock if user backs out without recording. |

### 3.3 Submissions (the upload flow)

Three-phase resumable upload using R2's S3-compatible multipart API. The app does the chunking; the server only mints presigned URLs.

| Method | Path | Notes |
|---|---|---|
| `POST` | `/v1/submissions/init` | Body: `{ reservationId, sessionId, sizeBytes, fileCount, metadata }`. Returns `{ submissionId, uploadId, partUrls[] }`. `partUrls` is presigned PUT URLs for each 8MB chunk. // tunable |
| `POST` | `/v1/submissions/:id/complete` | Body: `{ parts: [{ partNumber, etag }] }`. Server calls R2 `CompleteMultipartUpload`, validates manifest against schema (v1 §5), enqueues `process_upload`, returns `{ status: "queued" }`. |
| `POST` | `/v1/submissions/:id/abort` | Releases multipart upload; reservation is also released. |
| `GET`  | `/v1/submissions/:id` | Polled by app for status. Returns `{ status: "review" | "approved" | "rejected", points?, rejectionReason? }`. |
| `GET`  | `/v1/submissions?cursor=&status=` | Lists for current user. Drives Files screen. |

**Resumability:** if the app loses network mid-upload, on resume it calls `GET /v1/submissions/:id/parts` → returns `[{ partNumber, etag }]` already received → app re-mints presigned URLs only for the missing parts via `POST /v1/submissions/:id/parts/sign`.

**Chunking:**
- Chunk size: 8 MB. // tunable
- Upload only on Wi-Fi by default; cellular toggle hidden in Settings → Data.
- Concurrency: 3 parallel parts max (low-end CPU friendly).
- Per-part timeout: 30s. Retry with exponential backoff (1s, 2s, 4s, 8s; cap 5 attempts per part).
- Persist progress in Hive `outbox` box (v2 §6) so a kill-9 doesn't lose progress.

**Bundle layout uploaded:** the v1 §5 directory packed as `recording_<sessionId>.tar.gz`. R2 object key: `submissions/{userId}/{yyyymmdd}/{sessionId}.tar.gz`.

### 3.4 Profile, points, leaderboard

| Method | Path | Notes |
|---|---|---|
| `GET` | `/v1/me` | Profile + balance + pending. Cache 30s. |
| `GET` | `/v1/me/contributions` | Hours, submitted count, approval rate. |
| `GET` | `/v1/me/capabilities` | Returns the 6 radar dimensions, each `0–1`. Computed server-side weekly. |
| `GET` | `/v1/me/ledger?cursor=&limit=` | Points ledger entries: `{ id, type: 'credit'|'debit', amount, reason, refSubmissionId?, ts }`. |
| `GET` | `/v1/leaderboard?scope=global|region&window=alltime|month` | Top N + window around `me` (±2). Returns 5 rows by default. |

### 3.5 Notifications (push)

| Method | Path | Notes |
|---|---|---|
| `POST` | `/v1/devices/register` | Body: `{ apnsToken | fcmToken, platform }`. |
| `DELETE` | `/v1/devices/:id` | On logout. |

Server pushes for: `submission.approved`, `submission.rejected`, `points.credited`, `task.deadline_soon` (when user has reserved a slot). Each push deep-links per v2 §5.

### 3.6 i18n content

Task titles, publisher names, steps, lighting/surface notes are localized server-side.

| Method | Path | Notes |
|---|---|---|
| `GET` | `/v1/tasks/:id?locale=fr` | Returns localized strings; falls back to en. |
| `GET` | `/v1/categories?locale=id` | Same. |

UI strings stay client-side (ARB). Only *content* is server-side.

## 4. Data Model (Postgres)

```sql
-- core
create table users (
  id            uuid primary key,
  uid           text unique not null,            -- DGT-XXXXXXXX
  display_name  text not null,
  phone         text unique,
  email         text unique,
  locale        text default 'en',
  created_at    timestamptz default now()
);

create table categories (
  id text primary key,
  name_key text not null,                        -- i18n key
  glyph text not null,
  coming_soon bool default false,
  sort_order int
);

create table publishers (
  id uuid primary key,
  name text not null,
  verified bool default false
);

create table tasks (
  id uuid primary key,
  category_id text references categories(id),
  publisher_id uuid references publishers(id),
  title_key text not null,
  difficulty text check (difficulty in ('easy','medium','hard')),
  duration_min int, duration_max int,            -- seconds*60
  lighting text, surface text,
  steps jsonb not null,                          -- array of i18n keys
  demo_video_url text,
  reward_points int not null,
  total_slots int, slots_filled int default 0,
  deadline timestamptz,
  created_at timestamptz default now()
);

create table reservations (
  id uuid primary key,
  user_id uuid references users(id),
  task_id uuid references tasks(id),
  expires_at timestamptz not null,
  released bool default false
);

create table submissions (
  id uuid primary key,
  user_id uuid references users(id),
  task_id uuid references tasks(id),
  session_id uuid not null,                      -- matches metadata.json
  reservation_id uuid references reservations(id),
  size_bytes bigint,
  duration_sec real,
  r2_key text,                                   -- once complete
  status text not null check (status in ('uploading','queued','processing','review','approved','rejected')),
  rejection_reason text,
  approved_at timestamptz,
  created_at timestamptz default now()
);

create table points_ledger (
  id uuid primary key,
  user_id uuid references users(id),
  type text check (type in ('credit','debit','reserve','release')),
  amount int not null,
  reason text,
  ref_submission_id uuid references submissions(id),
  ts timestamptz default now()
);
create index on points_ledger (user_id, ts desc);

create materialized view leaderboard_global as
  select user_id, sum(duration_sec)/3600 as hours, sum(case when type='credit' then amount else 0 end) as pts
  from submissions s join points_ledger p on p.ref_submission_id = s.id
  where s.status = 'approved'
  group by user_id;
-- refreshed every 5 min via scheduled Worker
```

## 5. Review Workflow

The review console is a separate web app (not in this doc), but the contract:

- Reviewer fetches `GET /v1/admin/submissions?status=review` (admin-scoped JWT).
- Streams the recording via signed R2 URL.
- `POST /v1/admin/submissions/:id/approve { points }` or `/reject { reason }`.
- On approve: insert `points_ledger` `credit`, update `submissions.status`, push to user.
- On reject: update status + reason, push to user. **No points changed** (we never debited; pending = computed view of `submissions.status='review'`).

**Pending balance** is `SUM(tasks.reward_points)` joined to `submissions WHERE status IN ('uploading','queued','processing','review')` — never stored, always computed.

## 6. Upload Pipeline (GPU side, brief)

Out of strict scope but the contract:

- R2 PUT event → Cloudflare Queue → Modal worker.
- Worker downloads the tar.gz, validates against v1 §5 schema (using the validator script), runs HaWoR + depth, writes outputs to `processed/{sessionId}/`.
- Updates `submissions.status` to `processing` → `review`.
- Triggers review console notification.

## 7. Mock → Real Cutover Plan

Order matters; each step is independently shippable.

1. **Auth** (replaces all hard-coded "Maya Chen"). After this, fixtures still work but UID is real.
2. **`/me` endpoint** — wires up Profile header + balance/pending tiles.
3. **Categories + tasks list** — replaces `CATEGORIES` and `TASKS` constants in `screens-core.jsx`.
4. **Task detail** — replaces the prop-passed task object.
5. **Reservations** — adds the `POST /reserve` call when user taps Record. UI shows a 30-min countdown in the Recording HUD.
6. **Submission upload** — biggest milestone. Replaces v1's "share sheet" path. Share remains as a fallback in Settings → Developer.
7. **Submission status polling** — populates real `status` and `rejectionReason` in Recordings list + detail.
8. **Points ledger + capabilities** — wires up Profile radar and contributions.
9. **Leaderboard** — Profile bottom block.
10. **Push notifications** — last; everything works without them.

Each step flips one Riverpod provider from `FixtureXxxRepository` to `HttpXxxRepository`. The widgets do not change.

## 8. Deployment

### 8.1 Environments

| Env | API host | R2 bucket | DB | Notes |
|---|---|---|---|---|
| `dev` | `api.dev.digients.dev` | `digients-recordings-dev` | Neon dev branch | reset weekly |
| `staging` | `api.staging.digients.dev` | `digients-recordings-staging` | Neon staging branch | feature freeze for QA |
| `prod` | `api.digients.dev` | `digients-recordings` | Neon prod, PITR enabled | |

App build flavors map 1:1: `flutter build apk --flavor=staging --dart-define=API_BASE=https://api.staging...`.

### 8.2 CI/CD

- **API:** GitHub Actions → Wrangler deploy on push to `main` (dev), tag `staging-*` (staging), tag `prod-*` (prod, manual approval).
- **DB migrations:** `drizzle-kit` migrations stored in `api/migrations/`, applied as a step before deploy. Forward-only; no auto-down.
- **Mobile app:**
  - Android: GitHub Actions → Fastlane → Play Console internal track on `main`, beta on tag `staging-*`, production on tag `prod-*` (manual rollout 10/50/100%).
  - iOS: GitHub Actions → Fastlane → TestFlight on `main`, App Store on tag `prod-*`.
- **Review console:** separate repo, Pages deploy.

### 8.3 Observability

- Workers logs → Cloudflare Logpush → S3-compatible sink for grep/replay.
- Errors → Sentry (mobile + worker, separate projects).
- Metrics: Cloudflare Analytics + a custom dashboard on Grafana Cloud — submissions/day, p50/p95 upload duration by region, reject rate per category, slot fill rate.
- App-side: opt-in telemetry only (off by default in low-trust regions).

### 8.4 Secrets

- Wrangler secrets for: `JWT_SIGNING_KEY`, `R2_ACCESS_KEY`, `R2_SECRET`, `DB_URL`, `TWILIO_*`, `APNS_*`, `FCM_*`, `SENTRY_DSN`.
- Mobile: only `API_BASE` + `SENTRY_DSN` baked in via `--dart-define`. **No** server secrets in the mobile bundle.

### 8.5 Rate limits & abuse

- Auth start: 5/hour per phone number, 30/hour per IP.
- Submissions/init: 10/hour per user. // tunable
- Multipart parts: no per-call limit, but 1 GB/hour total upload per user. // tunable
- Cloudflare Turnstile on `/auth/start` to deflect headless OTP spam.

### 8.6 Data retention & privacy

- Raw uploads in R2: kept until processing complete + 30 days for QA.
- Approved recordings: archived to a colder R2 storage class.
- Rejected recordings: deleted after 7 days (configurable per region).
- User-side delete: hard-delete from R2 + DB on `DELETE /v1/me`. Tombstone retained 30 days for audit.
- No biometric/face data storage. Frames ARE the data, but per v1 audio is never captured. Add a region-flagged blur step in the GPU pipeline if required by jurisdiction (TBD with legal).

## 9. Testing

- **Contract tests:** OpenAPI spec (`openapi.yaml`) generated from Hono routes. Mobile generates Dart client from it (`openapi-generator`).
- **Mock server:** Prism running off the OpenAPI spec — used by the v2 fixture repositories during dev.
- **Upload soak test:** simulate 100 concurrent users on flaky 3G via `tc netem`. Expect zero data loss; expect resumes to complete within 3× ideal time.
- **Failure modes covered in CI:**
  - mid-upload kill-9 → resume succeeds
  - server returns 500 on `complete` → app retries with same `uploadId`
  - manifest fails schema validation → `rejected` with explicit reason
  - clock skew >5 min → JWT refresh handles it

## 10. Open Questions

1. **OTP delivery in low-coverage regions** — Twilio is fine for SEA, may need a regional aggregator for parts of Africa. // research
2. **GPU runner pricing** — Modal vs. Runpod vs. self-managed; budget caps in §8.5 assume ~$0.30/min of footage processed. Validate.
3. **Capability radar formula** — currently "approval rate per category, normalized." Capability dim "Speed" needs a definition: `submissions per active hour`? `record-to-submit latency`? Pick one before shipping the radar.
4. **Slot fairness** — first-come reservation can be gamed by bots. Consider per-publisher daily caps per user.
5. **Cellular upload opt-in copy** — needs UX writing pass; default "Wi-Fi only" is fine but the fallback path needs friendly framing.
6. **Review console SLA** — what's the target review turnaround? V2 copy literally promises "48 hours". If we can't hit that, change the copy.
7. **Refunds on rejection** — does the user have an appeal path? Out of scope for v3.0; ticket it.

---

**Sign-off needed from:** platform lead (architecture), data-pipeline lead (R2/queue boundary), legal (data retention, regional privacy), product (review SLA copy).
