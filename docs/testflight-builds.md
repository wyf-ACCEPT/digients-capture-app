# TestFlight Build Log

Reverse-chronological record of every build uploaded to App Store Connect.
Update on each upload — keep entries terse and focused on what changed
since the previous build.

| Build         | Uploaded   | Backend          | Notes |
|---------------|------------|------------------|-------|
| **0.2.2 (5)** | 2026-05-15 | AWS Lambda       | Tier 1 (wakelock + banner) bundled with Tier 2 **Phase A spike**. Adds throwaway `/dev/upload-spike` route accessible from Settings → DEV section, where a recording can be uploaded via `background_downloader` (iOS background URLSession) instead of dio. Spike runs the same `/v1/submissions/{init,complete}` legs but swaps the S3 PUT for an `UploadTask` so the transfer survives lock-screen / app-switch / jetsam. **Main upload path on the submissions list is still dio — this build only proves the new path works on real iOS 26.4; Phase B–D fold it into production.** Dylan is testing two things separately: (a) wakelock prevents auto-screen-lock during a main-path upload, (b) spike screen upload survives a real screen lock. |
| 0.2.2 (4)     | 2026-05-15 | AWS Lambda       | Tier 1 background-suspension band-aid: hold `WakelockPlus` while any upload is in flight, and surface a "keep app open" banner on the submissions screen while uploads are queued/running. Addresses Dylan's factory feedback that 3.5 GB takes consistently failed when the phone auto-locked or got switched away from. Does **not** solve manual lock / app-switch / app-kill — that's Tier 2 (background URLSession via background_downloader), planned in `.claude/plan/6e15-plan-background-upload.md`. |
| 0.2.2 (3)     | 2026-05-15 | AWS Lambda       | Restored two-square layout (upload + delete) on submissions list rows; export moved to the detail screen per Dylan + Ziyu feedback that the cloud-upload pill was less prominent than the old delete+share affordance. Mid-bottom progress pill stays as display-only. Also: `main.dart` `API_BASE` default fallback now points at `api.digients.tech` instead of the retiring CF Workers URL — fixes the invite-code 401 caused by silent fallback to the orphan D1. |
| 0.2.2 (2)     | 2026-05-14 | AWS Lambda       | Fix multi-GB upload OOM crash. Replaced `package:http` `StreamedRequest` with `dio` for the S3 PUT — dio applies real backpressure through `Stream<List<int>>` so memory stays bounded, and `onSendProgress` reflects true network throughput instead of disk-read speed. Also bumped upload timeout 30 min → 2 h to accommodate multi-GB takes over typical home upload bandwidth. Multipart upload is the durable fix and remains planned. |
| 0.2.2 (1)     | 2026-05-14 | AWS Lambda       | Backend cutover to `api.digients.tech` (AWS Lambda + Aurora). Old builds keep defaulting to CF Workers via `String.fromEnvironment` fallback; this build is the first to point at AWS. No user-facing behavior change. Known bug (fixed in 0.2.2+2): 3.5 GB+ uploads OOM-crash because the underlying http client buffers the file in RAM. |
| 0.2.1 (2)     | 2026-05-14 | CF Workers       | Build-number bump for upload-pipeline validation. Not actually delivered to ASC (altool TLS abort caused by local DNS hijack — see CLAUDE.md). Effectively skipped. |
| 0.2.1 (1)     | 2026-05-13 | CF Workers       | Real S3 upload pipeline went live (`/v1/submissions/init` → presigned PUT → `/complete`). First TestFlight build that actually uploads recordings to `digients-recordings-sg`. |
| 0.2.0 (3)     | 2026-05-10 | CF Workers       | _(fill in if remembered — likely fix iteration on top of 0.2.0+2)_ |
| 0.2.0 (2)     | 2026-05-10 | CF Workers       | Replaced Apple/Google sign-in buttons with a single "Skip sign-in" CTA for Beta Review — works around not yet having Apple Sign-In configured on the company team. |
| 0.2.0 (1)     | 2026-05-09 | CF Workers       | First build under the company Apple Developer team (`FTTNZLDA35`, bundle `tech.digients.capture`). Real `HttpAuthService` wired against CF Workers backend; mock auth retired. |
| 0.1.0 (2)     | 2026-05-07 | (mock auth)      | _(intermediate iteration on top of 0.1.0+1 — fill in if remembered)_ |
| 0.1.0 (1)     | 2026-05-07 | (mock auth)      | First-ever TestFlight build, under personal Apple Developer account. Capture engine + v3 auth scaffolding with mock auth service. `NSMicrophoneUsageDescription` added on the same day to satisfy ASC static analyzer error 90683 (no actual mic capture). |

## Conventions

- Marketing version (`x.y.z`) bumps when there's a meaningful user-visible change
  or backend cutover that justifies a full Beta App Review pass.
- Build number (`+n`) bumps for upload re-attempts, signing fixes, or
  internal-only changes that ride on the same Beta Review approval.
- Internal-only distribution (group type 内部) doesn't require Beta Review;
  external groups do.
- Always include which **backend** the build points at — this is the single
  most important fact when triaging "why doesn't login work" reports.
