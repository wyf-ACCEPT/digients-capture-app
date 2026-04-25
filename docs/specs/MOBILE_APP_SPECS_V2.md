# MOBILE_APP_SPECS_V2.md — Digients Capture · UI Layer

> **Scope.** This document specifies the UI layer to be built on top of the v1 capture engine (Flutter + native intrinsics described in `MOBILE_APP_SPECS_V1.md`). v1 stands; nothing in section 2–6 of v1 changes. v2 adds a complete user-facing surface: 10 screens, a design system, a navigation graph, a local-first state model, and the placeholders that v3 (backend) will eventually replace.
>
> **Companion mockup.** `Digients Capture v2 UI.html` (this project) — 10 static artboards on a design canvas + 1 fully clickable prototype.
>
> **Companion doc.** `MOBILE_APP_SPECS_V3_TBD.md` — backend, R2 upload, and deployment.

---

## 1. Goals

1. Replace the v1 dev-grade UI with a polished, low-literacy, large-target interface aimed at crowd-sourced data collectors in emerging markets.
2. Wrap the existing capture engine without changing the v1 data contract (Section 5 of v1).
3. Stand up the full task discovery → record → submit → review status loop, with placeholders where the backend isn't ready yet, so v1 capture can ship behind real product chrome.
4. Architect for i18n from day one (English first, then French, Bahasa Indonesia, Vietnamese, Tagalog).
5. Stay performant on sub-1000-RMB Android devices.

## 2. Tech Stack (additions to v1)

| Concern | Choice | Notes |
|---|---|---|
| State | `riverpod` (or `provider` if team already standardized) | Sync state only; persist to Hive. |
| Local DB | `hive_ce` (boxed) | Recordings index, draft submissions, cached task list, user profile. |
| Routing | `go_router` | Deep-linkable; required for push notification → screen handoff in v3. |
| i18n | Flutter's built-in `intl` + `.arb` files | One ARB per locale under `lib/l10n/`. |
| Fonts | Inter (UI), JetBrains Mono (data) — bundled, **not network** | Network fonts fail on intermittent rural connections. |
| Icons | Custom SVGs in `assets/icons/` (already in mockup) | No icon-font deps. |
| Animations | `flutter_animate` for entry/exit; `lottie` only for the success confetti | Avoid heavyweight motion libs. |
| Haptics | `flutter/services` `HapticFeedback` | Critical for storage-near-full warning and Stop button. |

**Do not add:** Firebase UI Kit, GetX, design-system packages from pub. Roll our own — easier to keep the look consistent and easier to drop network deps later.

## 3. Design System

### 3.1 Color tokens (CSS-style names; map 1:1 to Dart `Color` constants in `lib/theme/tokens.dart`)

**Dark (default)**
| Token | Hex | Usage |
|---|---|---|
| `bg` | `#0A0A0A` | Screen background |
| `surface` | `#141414` | Cards, sheets |
| `surface-2` | `#1C1C1C` | Pressed cards, inputs |
| `border` | `#1F1F1F` | Hairlines |
| `border-strong` | `#2A2A2A` | Card borders |
| `text` | `#FAFAF7` | Primary text |
| `text-dim` | `#8A8A8A` | Secondary text, mono labels |
| `text-faint` | `#555555` | Tertiary, timestamps |
| `accent` | `#14C9A8` | CTA, points, record dot, brand (teal) |
| `accent-glow` | `rgba(20,201,168,0.35)` | CTA shadow |
| `accent-tint` | `rgba(20,201,168,0.08)` | Subtle accent backgrounds (selected row, uploading badge) |
| `success` | `#14C9A8` | Approved badge, slot count (= accent — single brand color) |
| `warning` | `#FFB800` | Pending points, in-review badge |
| `danger` | `#FF453A` | Rejected, delete |

**Light** — same names, inverted; see `styles.css` `[data-theme="light"]` block in mockup. Both themes ship in v2; default is dark. Tweak surfaced via Settings.

### 3.2 Typography

- **Display / Title:** Inter 700, letter-spacing -0.02em to -0.03em, `text-wrap: balance`.
- **Body:** Inter 500 / 400, 14–15px, line-height 1.5.
- **Mono (data, timers, IDs, labels):** JetBrains Mono 500/600, often with `text-transform: uppercase; letter-spacing: 0.14em` for eyebrow labels.
- **Minimum body size:** 13px. Eyebrow labels: 10–11px is OK *only* in mono uppercase.

### 3.3 Spacing & touch targets

- 8pt baseline grid. Common paddings: 12 / 14 / 16 / 20 / 24.
- **Minimum tap target: 44dp.** Enforced in code review.
- Card radius: 14–18 for content cards, 12 for stat tiles, 10 for metadata key-value tiles, 999 for pills/CTAs.

### 3.4 Component primitives

Mirror the mockup's Dart components:

- `DCButton.primary` (`.cta`) — full-width pill, accent fill, pressed scale 0.98.
- `DCButton.secondary` (`.cta-secondary`) — surface fill, border-strong outline.
- `DCChip` — filter pill; active = inverted (text bg + bg fg).
- `DCStatusBadge` — review/approved/rejected; mono uppercase, dot prefix, tinted bg.
- `DCPointsPill` — accent fill, mono, used for `+580` etc.
- `DCCategoryCard` — masonry tile with backdrop glyph.
- `DCTaskCard` — half-screen card: image + tag chip + title + publisher + duration + slots.
- `DCRecordingRow` — list row with thumbnail, status, points.
- `DCKVTile` — mono key on top, mono value below; used in Recording Detail.
- `DCRadar` — 6-axis radar chart (Profile).
- `DCNavBar` — back chevron + title + optional sub + right slot.
- `DCTabBar` — 3 tabs: Home / Submissions / Me. Active = filled icon + text in `text`.
- `DCImagePlaceholder` — striped diagonal pattern, mono caption. **Use for every image until we have real assets.**

### 3.5 Motion

- Press: 120ms scale 0.97–0.98.
- Sheet/screen entry: 250–500ms `fadeUp` (translateY 8 → 0 + opacity).
- Submit Success: 500ms `scaleIn` on the check, 2.5–3.5s confetti, copy fades through 3 lines (~7s) until user taps Go To Submissions.
- Recording dot: 1.4s ease-in-out infinite pulse.
- **Disable all non-essential animation** when `MediaQuery.disableAnimations == true` (low-end mode).

## 4. Screens

The IA is a 3-tab bottom nav with a stack inside each tab. The Recording screen is *modal* (covers the tab bar).

```
[Tab: Home]         00 Auth → 01 Home → 02 Pool → 03 Detail → 04 Recording (modal) → 05 Success
[Tab: Submissions]  06 Submissions list → 07 Submission Detail
[Tab: Me]           08 Profile → 09 Settings

No first-run calibration. Recording auto-uses the device's widest-FOV rear camera with intrinsics queried per-frame (v1 §3.3); we no longer block users on a calibration step — it created drop-off without a quality benefit.
```

Numbered to match the mockup artboard labels.

### 4.0 Sign In / Register

First screen on cold launch when no auth session is present.

- **Hero:** product mark (gradient camera glyph) + headline ("Welcome back" or "Create account") + 1-line subtitle.
- **Method tabs:** segmented Phone / Email picker (default Phone).
- **Identifier field** + **OTP field** (OTP appears after tapping "Send verification code"; shows a 60s countdown via mono caption).
- **Primary CTA:** "Send verification code" → "Sign in" / "Create account" once OTP is entered.
- **OAuth divider** + Apple / Google buttons (side-by-side).
- **Switch link:** "Don't have an account? Register" / "Already have an account? Sign in".
- **Register variant** adds a Terms/Privacy disclosure line above the CTA.
- **v2 mockup behavior:** every CTA — primary, OAuth, OTP — calls `onAuth()` and lands on Home regardless of input. Inputs are unvalidated. This is a placeholder; the real auth flow is gated behind v3 (see V3 spec §3.1).
- **Backend dependency:** `/v1/auth/*` endpoints (V3). v2 has no session model.

### 4.1 Home

- Greeting + avatar (avatar opens Profile).
- **Balance / Pending strip** — two equal columns inside one card, mono numerals.
- **Category masonry** — 2-col grid, 4 active categories + 2 "Soon" ghosts. Tall cards (220px) for Household / Daily Life; short (168px) for the rest. Background glyph at 35% opacity bottom-right.
- Tap → push Pool screen with that category.
- **Backend dependency:** points balance, pending balance, per-category open count, "Soon" flags. Until v3: hard-coded mocks (see `screens-core.jsx`).

### 4.2 Task Pool

- Nav bar: category title + sub "N tasks · sorted by reward".
- Filter chip row (horizontal scroll): All / High Reward / Quick (<3 min) / Beginner / Verified.
- Task cards (full-width, ~220px tall): hero image (placeholder) + tag chip + points pill (top-right) + title + publisher + duration + slots.
- Tap → Task Detail.
- **Backend dependency:** task list query with filter + sort. Until v3: per-category fixtures.

### 4.3 Task Detail

- Hero (demo video/image placeholder, 200px).
- Tag chip + publisher.
- Big title (26px, balance wrap).
- **Reward block:** lightning glyph + `+580` (36px accent mono) + "points on approval".
- **Spec grid** (2×2): Duration, Difficulty, Lighting, Surface.
- **Steps list** — numbered circles, hairline dividers, 14px text.
- **Heads-up block:** "Recording will auto-stop at 5% remaining storage. Phone will buzz to alert you." (literal copy.)
- **Sticky bottom:** mono row with `<Storage> {h}h {m}m available · {GB} GB free` + primary `Record` button (white inner dot + label). Storage time computed client-side: `floor(usable_GB × 1024 / 112)` minutes, where `usable_GB = free_GB × 0.95`.
- **Backend dependency:** task detail fetch. Until v3: pass the task object from Pool.

### 4.4 Recording (modal)

This is the only screen that takes over the OS chrome. Black background, no tab bar.

- **Default state:** minimal HUD pill at top — pulsing red dot + `mm:ss` mono. Bottom: 80px white-ringed stop button with accent square. Below it: mono caption "Tap to stop".
- **Expanded HUD (tap pill):** glass card with task title + 6 mono stats: `FPS 30 · Codec HEVC · Lens Ultrawide · Bitrate 15 Mb/s · Stab OFF · Intrinsics LIVE`. Storage progress bar at bottom (turns accent-red below 15%).
- **Auto-stop:** when storage falls below 5% headroom (per v1 §3.6 + v2 client computation), trigger `HapticFeedback.heavyImpact()` 3× and stop. Show a mid-stop banner: "Storage low — recording saved." Then transition to Success.
- **Background camera feed:** the live preview goes here in production. In the mockup, a radial gradient + 3×3 grid overlay + ghost hand outline stand in. **The mockup is not a video player** — production replaces this layer with the v1 native preview surface.
- **Backend dependency:** none. Capture is fully local per v1.

### 4.5 Submit Success

- Full-screen overlay with confetti (26 dots, 4 brand colors, 2–3.5s float-and-fade).
- Big accent circle + check icon (`scaleIn` 500ms).
- Headline "Submitted!" + a 3-line rotating sub that fades through (each line ~2.4s):
  1. "Data is uploading and will be under review."
  2. "Please keep internet connection."
  3. "Points will be credited within approximately 48 hours."
- Mono pill with `+points` and "pending review".
- **Primary CTA "Go To Submissions"** (replaces auto-dismiss). User taps to land on the Submissions tab where their just-recorded session appears at the top with status `uploading` (if upload started) or `ondevice` (if Wi-Fi-only is on and they're on cellular).
- **Backend dependency:** submission API call (v3). For v1 fallback: this screen runs after the user has shared the file via the share sheet (v1 §3.6); the "submission" is the share gesture.

### 4.6 Submissions

Polished version of the v1 file list. Renamed from "Recordings" — the list shows the user's *submissions to the platform*, in every state from "recorded but not uploaded" through "approved".

- Title + meta line ("6 total · 2.81 GB on device").
- Filter chips (6): **All / On Device / Uploading / In Review / Approved / Rejected**.
- List rows: 76px square thumbnail (duration overlay) + task title (2-line clamp) + date + size + status badge.
- **Inline row-level action button** on the right side of each row:
  - status `ondevice` → **Upload icon** (filled accent button). Tap = enqueue upload (does NOT navigate).
  - status `uploading` → no icon (progress shown via thumbnail mask + percentage).
  - status `review` / `approved` / `rejected` → **Trash icon** ("Delete from device" — the file is on the server, freeing local space). Tap = confirm dialog → delete the local copy.
- Tapping anywhere else on the row → Submission Detail. Inline icon clicks must `stopPropagation()`.
- **Backend dependency:** status + credited points are server-side fields. Local-first: rows start `ondevice`, transition `uploading` → `review` once R2 upload completes, then `approved` / `rejected` after moderation. See V3 §6.

### 4.7 Submission Detail

Nav-bar title is **"Submissions"** (not "Recording") so users understand they're inside the submissions flow.

- Hero placeholder + duration overlay.
- Status badge (5 states: ondevice / uploading / review / approved / rejected).
- Task title (22px, balance).
- **Status block per state:**
  - `ondevice`: surface card "Saved on device. Not uploaded yet. Submit when on Wi-Fi to start the review process. Pending reward: +N".
  - `uploading`: accent-bordered card with live percentage + thin progress bar + ETA mono caption "~Ns remaining · keep app foregrounded".
  - `review`: warning-tinted card "Submitted. Approval typically takes ~48 hours. Pending: +N".
  - `approved`: success-tinted card "Credited · Settled to your balance · +N".
  - `rejected`: danger-tinted card "Rejection reason: {reason}. Try again with steadier hand and bright, even lighting."
- 2×3 KV grid: Session ID, Captured, Size, Codec, Resolution, Intrinsics.
- **Action bar varies by state:**
  - `ondevice`: `[Upload]` (primary) + `[Trash]` (delete local).
  - `uploading`: `[Pause]` + `[Cancel upload]` (danger).
  - `review` / `approved` / `rejected`: `[Delete from device]` only — server has the file, this clears local.
- **Backend dependency:** rejection reasons are server-driven (free text from review console).

### 4.8 Profile

- Header: avatar (gradient with initials) + name + UID (mono, copyable on long-press) + Settings gear.
- 2-col stat tiles: Balance / Pending.
- 3-col contributions: Hours / Submitted / Approval%.
- **Capability radar (260×260):** 6 axes — Household, Industrial, Sports, Variety, Speed, Approval. 4 concentric polygons at 25/50/75/100%, accent-filled value polygon at 20% opacity, accent-stroked, point dots. Axis labels in mono 11px outside the outer ring.
- **Leaderboard:** top 3 + your row + ±1 neighbor (5 rows total). Your row is highlighted with accent-tinted bg. Mono columns for hours and points.
- **Backend dependency:** all of it. Until v3: fixtures.

### 4.9 Settings (subordinate to Profile, accessible via gear)

Deliberately minimal — capture parameters (resolution, codec, bitrate, stabilization, auto-stop threshold) are **not** user-tunable. They're locked to the v1 spec values to guarantee uniform training data quality across the entire collection fleet. Exposing them would let well-meaning users degrade the dataset.

**Sections:**
- **Account:** Avatar (tap row to upload from photo library / camera), Email, Phone (masked), UID (mono).
- **Uploads:** Wi-Fi-only toggle, Auto-upload after capture toggle, Background uploads toggle.
- **Notifications:** Approval results, Points credited, New tasks in your categories.
- **Appearance:** Theme (segmented: Auto / Dark / Light, default Auto).
- **About:** Version (mono), Privacy Policy, Terms of Service, Open-source licenses.
- **Danger zone:** Sign Out, Delete account.

## 5. Navigation Graph

```dart
/calibrate                       // first-run gate
/                                // Home (tab)
/pool/:categoryId                // Task Pool (tab when categoryId is unset)
/task/:taskId
/record/:taskId                  // modal — fullScreenDialog
/success/:sessionId
/submissions                     // Submissions tab
/submissions/:sessionId          // Submission Detail
/me                              // Profile tab
/me/settings
```

`go_router` ShellRoute for the 4 tabs; `record` is outside the shell so it covers the tab bar.

## 6. State & Persistence

### 6.1 Hive boxes

| Box | Key | Value |
|---|---|---|
| `recordings` | `sessionId` | `RecordingMeta { sessionId, taskId, taskTitle, capturedAt, duration, sizeBytes, status, points, rejectionReason?, exportedAt? }` |
| `tasks_cache` | `categoryId` | `List<Task>` + TTL — used for offline browsing |
| `profile` | `'me'` | `Profile { uid, displayName, balancePoints, pendingPoints, hoursLogged, submittedCount, approvalRate, capabilities[6] }` |
| `prefs` | various | theme, locale, last-seen leaderboard rank |
| `outbox` | `sessionId` | submissions queued for upload (v3) |

### 6.2 Local-first invariants

- Every screen reads from Hive first; network refresh is opportunistic.
- A recording is **never** deleted locally until `status == approved && exportedAt != null` (or user explicitly forces delete).
- Status fields default to `review` on creation; v3 sync overwrites.

## 7. i18n

- Every visible string lives in `lib/l10n/intl_en.arb`. No string literals in widgets.
- Mono labels (e.g., "BALANCE", "PENDING", "STEPS") are translated *with* their casing convention — uppercase becomes the language's idiomatic eyebrow style (e.g., French uses small caps via CSS; Asian scripts use bracketed labels).
- Dates / numbers via `intl` formatters. Never hand-format.
- Number rendering: `4,280` for en; `4 280` for fr; etc. Do **not** mono-pad.

## 8. Accessibility & Low-End Targets

- Minimum supported: Android 8 / iOS 15 (matches v1).
- All interactive elements have `Semantics(label: ...)`.
- All non-decorative SVGs have alt text via `Semantics`.
- Test on a 1000-RMB device (Tecno Spark or equivalent): the Home + Pool screens must scroll at >55fps; Recording must stay at 30fps capture.
- `MediaQuery.textScaler` honored everywhere — no fixed-pixel text rows.
- High-contrast mode: bump `border` and `border-strong` opacities; tested manually.

## 9. Placeholders & Mock-to-Real Cutover

Every screen with a `Backend dependency` line (above) ships **with a thin repository interface** so v3 can swap implementations without touching widgets:

```dart
abstract class TaskRepository {
  Future<List<Category>> categories();
  Future<List<Task>> pool(String categoryId, {Filter? filter});
  Future<Task> detail(String taskId);
}

// v2 ships this:
class FixtureTaskRepository implements TaskRepository { ... }

// v3 swaps to:
class HttpTaskRepository implements TaskRepository { ... }
```

Same pattern for `ProfileRepository`, `SubmissionRepository`, `LeaderboardRepository`. **Widgets must depend on the interface, never the impl.**

## 10. Deliverables

1. `lib/theme/` — tokens, typography, both themes wired through `ThemeData`.
2. `lib/widgets/` — every primitive in §3.4.
3. `lib/screens/` — one file per screen in §4.
4. `lib/repos/fixtures/` — fixture data matching the mockup (Households tasks, recordings, profile, leaderboard).
5. `lib/l10n/intl_en.arb` — complete English ARB.
6. `lib/router.dart` — go_router config per §5.
7. `lib/state/` — Riverpod providers + Hive boxes per §6.
8. **Storyboard parity test:** a Flutter golden-test file per screen, compared against PNG exports of the mockup artboards (within 5% pixel diff).
9. **Walkthrough video:** 60-second screen recording of the 4-tab IA on a real Android device, attached to the PR.

## 11. Out of Scope for v2

- Cloud upload (v3).
- Authentication (v3).
- Real backend for tasks, points, leaderboard, review status (v3).
- Push notifications (v3).
- In-app video playback beyond thumbnails (v1 §8 still holds).
- Live hand/depth overlay during recording.

## 12. Acceptance

The build is v2-complete when:

- All 10 screens exist and match the mockup within reason on a clean install.
- The 3-tab nav works with smooth tab switches.
- A first-run user can: browse Home → tap a category → tap a task → start recording → stop → see Success → tap "Go To Submissions" → land on Submissions tab with new entry.
- Submissions list shows the just-completed session with status `ondevice` (or `uploading` if Wi-Fi present and auto-upload on).
- Profile shows fixture data including the radar chart.
- The app is fully translated to English and at least one second locale (pick fr or id) end-to-end with no untranslated strings.
- App passes the `1000-RMB device` smoke test in §8.
