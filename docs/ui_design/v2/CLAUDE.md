# CLAUDE.md — Project handoff notes

> Read this first. Written by Claude for the next Claude (or human) picking up this project.

## What this project is

**Digients Capture** is a mobile data-collection app for embodied-AI / robotics training data. Humans mount their phone (typically on a headband, lens upward), record egocentric video of physical tasks (folding towels, opening bottles, sorting bolts), and submit recordings to a review pipeline. Contributors earn points per approved submission. Backend is on Cloudflare (Workers + R2 + D1).

This project is the **UI design layer** — a high-fidelity HTML/React prototype that serves as the visual reference for the Flutter implementation team. The v1 of the actual app already exists with rough UI; v2 is the polished UI redesign captured here.

## Source-of-truth documents

Read these in order:

1. **`uploads/MOBILE_APP_SPECS_V1.md`** — original product spec from the eng team. Covers the capture engine, file format, calibration, share-out flow. **Locked** for v2; the capture pipeline is not changing.
2. **`uploads/Digients Capture 精简后需求.md`** — the redesign brief (Chinese). The user's distillation of what v2 should look like and feel like. Treat as a description of intent, not literal layout.
3. **`MOBILE_APP_SPECS_V2.md`** — what we (you and the user) wrote together in this project. Spec of the v2 UI layer, screen by screen, with backend dependencies called out per screen. **This is the deliverable doc.** When the design changes, this doc must change too — they are paired.
4. **`MOBILE_APP_SPECS_V3_TBD.md`** — proposed v3 backend. Auth, real submissions API, Postgres schema, R2 multipart, review console contract, deployment, rate limiting. Not implemented; this is the engineering plan that turns the v2 mockup into a real product.

## The deliverable

**`Digients Capture v2 UI.html`** — open this in the preview pane. It contains:

- A **design canvas** (top section) showing all 11 screens as iPhone-framed artboards in order: 00 Auth → 01 Home → 02 Pool → 03 Detail → 04 Mount → 05 Recording → 06 Success → 07 Submissions → 08 Submission Detail → 09 Profile → 10 Settings.
- A **live prototype** (bottom section) — fully clickable. Starts on Auth, walks all the way through Submit Success → Submissions, with working tab nav and back buttons.
- A **Tweaks panel** (toolbar toggle) with theme switcher.

The user reviews mostly via the canvas, occasionally drives the prototype to check a flow.

## File / module layout

```
Digients Capture v2 UI.html    # entry point
styles.css                      # design tokens + global rules (cache-busted via ?v=N)
shared.jsx                      # Icon set, TopStatus, NavBar, TabBar, HomeIndicator, CategoryGlyph, ImagePlaceholder
app.jsx                         # main entry: <App> with DesignCanvas + Prototype, theme effect, TWEAK_DEFAULTS
screens-auth.jsx                # 00 Auth (login/register placeholder, OAuth, OTP)
screens-core.jsx                # 01 Home, 02 Task Pool, 03 Task Detail
screens-mount.jsx               # 04 Mount Instructions (animated SVG sequence)
screens-record.jsx              # 03 Task Detail's record CTA, 05 Recording (modal), 06 Submit Success
screens-files.jsx               # 07 Submissions, 08 Submission Detail, 09 Profile, 10 Settings
ios-frame.jsx                   # starter component (unused inside artboards — we use a custom <Frame> instead)
design-canvas.jsx               # starter component for the canvas wrapper
tweaks-panel.jsx                # starter component for the Tweaks panel
```

Everything is loaded as `<script type="text/babel" src="...">` in `Digients Capture v2 UI.html`. Components export themselves to `window` at the bottom of each file (Babel scopes per-script, so this is required).

## Design system

- **Aesthetic:** minimal black + single accent. Inspired by TikTok-dark but the accent is teal-green, not pink (user specifically rejected pink as too TikTok-ish).
- **Accent:** `#14C9A8` (teal). Used for CTAs, points, active states, status dots, focus rings.
- **Type:** Inter (UI) + JetBrains Mono (timer, UID, mono labels, technical metadata).
- **Tokens** live in `styles.css` `:root` (dark) + `[data-theme="light"]` (light). Use `var(--bg)` / `var(--surface)` / `var(--surface-2)` / `var(--border)` / `var(--text)` / `var(--text-dim)` / `var(--text-faint)` / `var(--accent)` / `var(--danger)`.
- **Frame:** all screens are 393×852 (iPhone 15 Pro). The `Frame` component in `app.jsx` wraps a screen with a faux iPhone bezel for the canvas; the prototype uses the same screens raw.
- **Status pills:** the `.status` class with modifier per status (`.ondevice`, `.uploading`, `.review`, `.approved`, `.rejected`). Defined in `styles.css`.

## CSS cache-busting

`styles.css` is loaded with `?v=N`. **Bump N every time you edit `styles.css`** or the user will see the stale stylesheet (this happened repeatedly in development). Current version is whatever's in the HTML — grep it.

## Conventions and gotchas

- **No emoji.** No iconography unless it earns its place. The user pushed back on icon clutter.
- **No filler content.** Don't pad screens with stats, badges, or copy that doesn't serve the design.
- **Status flow:** `ondevice` → `uploading` → `review` → `approved` | `rejected`. Five states everywhere; don't add new ones without checking.
- **Submissions row actions:** Upload icon on `ondevice`, Trash icon on `review/approved/rejected`, nothing on `uploading`. Both buttons have a default tinted background (mobile-first; can't rely on hover). See `.row-icon-btn` in `styles.css`.
- **Settings is deliberately minimal.** Capture parameters (resolution, codec, stabilization, auto-stop) are **not** user-tunable — they are locked in code to guarantee uniform training data. Don't reintroduce them.
- **Auth screen is a v2 placeholder.** Any input or no input → `onAuth()` lands on Home. Real OTP/OAuth is V3.
- **No first-run calibration.** Removed in early v2 iteration; the user explicitly killed it. v1's calibration UI was an onboarding drop-off without a quality benefit.
- **Tabs are 3, not 4:** Home / Submissions / Me. There is no separate "Tasks" tab; tasks live one tap deep from Home.
- **SVG can't take `fill="var(--accent)"`** — CSS variables don't work in SVG presentation attributes. Use inline `style={{ fill: 'var(--accent)' }}` instead. Bit me twice.
- **Style object naming:** every JSX file uses inline styles or a uniquely-named `xxxStyles` object. `const styles = {...}` collides across files and breaks Babel scope.

## How the user works

- Reviews via the design canvas (zoom + pan). Will sometimes ask "show me artboard 07" — that means the labeled artboard.
- Speaks Chinese mostly. Direct, terse feedback. When they say "丑" (ugly), they mean the visual treatment is wrong, not the layout — usually a button-vs-icon weight issue or a color too saturated.
- Doesn't want me to take screenshots and verify on every change — they'll tell me when something looks wrong.
- Final docs (V2 + V3) must stay in sync with the design. Every design decision that affects backend or product behavior gets captured in V2; every design decision that depends on backend work gets noted in V3.

## What's done

✓ All 11 screens designed, in canvas + prototype  
✓ V2 UI spec doc complete  
✓ V3 backend spec doc complete (TBD label is intentional — it's the engineering plan)  
✓ Theme switcher (Auto / Dark / Light) wired in Settings  
✓ Light theme palette  

## What's open / known

- **Avatar upload** in Settings is a placeholder row — no actual file picker hooked up (this is fine for v2 mockup).
- **Theme = "Auto"** in Settings doesn't actually wire to system `prefers-color-scheme` in the mockup; it's a visual placeholder. The Tweaks panel's theme toggle does work and forces dark/light. If the user wants Auto wired, it's a small change.
- **Localization:** mockup is English-only. V2 spec requires `.arb` files; not relevant to the design canvas.
- **Speaker notes / PDF export:** never set up. Not requested.

## When picking up this project

1. Open `Digients Capture v2 UI.html` in preview to see the current state.
2. Re-read `MOBILE_APP_SPECS_V2.md` end-to-end — it's the contract.
3. Skim `MOBILE_APP_SPECS_V3_TBD.md` for backend implications of any UI change.
4. The user usually opens with a numbered list of small fixes referencing artboard numbers ("07 Submission ..." or "10 Settings ..."). Match each item to a file:
   - `01-03` → `screens-core.jsx`
   - `04` → `screens-mount.jsx`
   - `05-06` → `screens-record.jsx`
   - `07-10` → `screens-files.jsx`
   - `00` → `screens-auth.jsx`
   - tokens / colors / spacing → `styles.css` (and bump `?v=N`)
5. Make the change. Run `done` on the HTML to confirm clean. End your turn — the user prefers tight iteration over verbose status updates.

## Useful invariants

- iPhone frame: 393 × 852, radius 56, bezel 12px, shadow `0 30px 80px rgba(0,0,0,0.45)`.
- TabBar height: ~83px including home indicator. NavBar height: ~52px including TopStatus.
- Surface-2 is 1 step lighter than surface in dark, 1 step darker in light.
- Recording screen is **modal** — covers the tab bar, owns the chrome.
- Submit Success has 3 fading copy lines and a "Go To Submissions" CTA (no auto-dismiss).
