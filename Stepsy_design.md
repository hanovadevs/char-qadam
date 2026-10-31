# Stepsy — UI/UX Redesign Brief

**Purpose of this document:** This is a design-and-build prompt. Hand this file directly to a coding agent (or a designer) as the instruction set for redesigning Stepsy's entire interface. It is written to be followed literally — every rule below is a requirement, not a suggestion, unless explicitly marked optional.

The current app (Steps, Points, Rewards, Wallet, Profile screens) is functionally complete but visually and verbally unfinished: harsh black borders, boxy sharp-cornered cards, all-caps labels everywhere, redundant subtitle text under nearly every header, and backend/dev terminology leaking into user-facing copy. This brief exists to fix all of that in one coherent pass — not screen by screen, patch by patch.

---

## 1. Design Principles (non-negotiable)

1. **Light theme only.** White and near-white surfaces throughout. No dark mode in this pass.
2. **Brand color only.** The only accent color anywhere in the app is the teal/emerald from the Stepsy logo (palette below). No blue links, no red/green traffic-light UI patterns except where explicitly noted for destructive actions.
3. **No emojis, anywhere**, in any string, empty state, or notification copy.
4. **Minimal icons.** Icons are used only for navigation (tab bar) and a small number of essential functional affordances (share, QR, back). They are never decorative. When in doubt, remove the icon and let typography and spacing carry the hierarchy instead.
5. **Apple-style navigation.** This means the actual iOS interaction model, not just "clean" styling — see Section 5 for specifics.
6. **Every word must earn its place.** If a subtitle, badge, or label doesn't add information the user doesn't already have from the element next to it, delete it. Section 8 and Section 9 identify every instance of this in the current app.
7. **This app touches real points and real money-adjacent vouchers.** The design should read as trustworthy and precise — generous whitespace, confident typography, no clutter — not playful or gamified in a way that undermines that trust.

---

## 2. Brand & Color System

Colors are sampled from the Stepsy logo (teal gradient "S" mark + dark wordmark). Verify exact hex values against the logo source file before finalizing — the values below are close working approximations.

| Token | Approx. Hex | Usage |
|---|---|---|
| `accent-bright` | `#2FE0C4` | Gradient start — hero moments only (progress rings, primary illustrations) |
| `accent-deep` | `#0B4A47` | Gradient end — paired with `accent-bright` |
| `accent-solid` | `#0F8A78` | Flat accent for text links, active icon states, primary buttons — the color used everywhere accent color is needed at small sizes |
| `ink-primary` | `#16213A` | Primary text — matches the wordmark's dark navy-charcoal, **not pure black** |
| `ink-secondary` | `#5B6472` | Secondary/supporting text |
| `ink-tertiary` | `#9AA3AD` | Placeholder text, disabled states, timestamps |
| `surface` | `#FFFFFF` | Cards, primary content surfaces |
| `surface-muted` | `#F3F6F5` | Grouped list backgrounds, screen background (very subtle, not stark white) |
| `hairline` | `#E7EBEA` | All dividers and card borders — 1px, never black |
| `destructive` | `#FF3B30` | Reserved exclusively for "Delete Account" and irreversible actions — nowhere else |

**Rule:** the gradient (`accent-bright` → `accent-deep`) is a special-occasion element — the step progress ring, the app's own icon, maybe one hero card. It is not a general-purpose button color. Buttons and interactive elements use flat `accent-solid`.

---

## 3. Typography

- Use a rounded-geometric sans-serif that echoes the wordmark's warmth — **SF Pro Rounded** on iOS, with **Inter** or **Manrope** as the cross-platform Flutter fallback so Android doesn't look like a different app.
- Follow the iOS type scale, not custom sizing per screen:

| Style | Size / Weight | Usage |
|---|---|---|
| Large Title | 34pt / Bold | Screen-level title, collapses on scroll (see Section 5) |
| Title | 22pt / Semibold | Section headers within a screen |
| Headline | 17pt / Semibold | Card titles, list row primary text |
| Body | 15–17pt / Regular | Body copy, descriptions |
| Caption | 13pt / Regular, `ink-secondary` | Timestamps, metadata, helper text |

- **No all-caps text anywhere**, except single-word status badges (e.g. "ACTIVE") where iOS convention already expects it. Section headers, labels, and buttons use normal sentence case.
- Numbers that are the hero of a screen (step count, points balance) get their own oversized numeral style — this pattern already exists in the current app and should be kept, just refined (larger, tighter tracking, `ink-primary`).

---

## 4. Navigation Pattern (Apple-style, specifically)

This means the following concrete behaviors, not just "looks like iOS":

- **Large Title → Small Title on scroll.** Each screen's title starts large (34pt) at the top and collapses into a small centered/inline title (17pt semibold) in the nav bar as the user scrolls down, per iOS's native large-title navigation controller pattern.
- **Translucent, blurred bars.** Both the top navigation bar and bottom tab bar use a translucent blur-over-content effect when content scrolls beneath them, not a solid opaque bar.
- **Tab bar:** 5 tabs (Steps, Points, Rewards, Wallet, Profile) stay as-is structurally. Icons are single-weight outline glyphs that switch to a filled variant when active, with the active tab's icon and label tinted `accent-solid` — everything else stays `ink-secondary`. No color anywhere else in the tab bar.
- **Grouped inset lists**, not bordered boxes. Settings-style screens (Profile) should use the native iOS grouped-list pattern: rounded-corner sections on a muted background, hairline dividers *between* rows, no border *around* each individual row. This directly replaces the current black-bordered box-per-row pattern.
- **Sheets for secondary actions**, not full navigation. Actions like "Edit Preferences," "Show QR," or filtering options should present as a bottom sheet/modal rather than a full page push, where the action is quick and doesn't need its own dedicated screen.
- **Swipe-back gesture** must work from anywhere on any pushed screen (standard iOS edge-swipe-to-go-back), not just a back button.
- **Segmented controls** (already used for "Today / 7D / 30D" and "Active / Used / Expired") are correct — keep this pattern, just restyle to the native iOS segmented control look: rounded pill container, sliding selection indicator, no hard borders.

---

## 5. Component Language

- **Cards:** Corner radius 16–20pt (continuous/"squircle" curve, not simple rounded rect). Background `surface`, 1px `hairline` border or a very soft shadow — never both, never a heavy black border.
- **Buttons:** Primary buttons are filled `accent-solid` with white text, corner radius matching the card system (not a harsh rectangle). Secondary/tertiary actions are text-only or outline, never a second filled black button competing with the primary action.
- **Badges/pills:** Keep these (they work well for "10% OFF," "In Stock," "Active") but restyle: soft-filled background using a tint of the relevant color rather than solid black-on-white.
- **Empty states:** "No step records for this period" and similar empty states need actual visual treatment — a centered icon-free message with `ink-secondary` text, generous vertical spacing — not a plain bordered gray box.
- **List rows:** Every list row (transaction history, settings rows, voucher list) follows one consistent row template: leading element (optional), title + optional single-line caption, trailing element (value, chevron, or control). No row should have more than one line of secondary text.

---

## 6. Iconography Rules

- Icons appear **only** in: the tab bar, and a small fixed set of functional affordances (share, QR code, refresh, chevron-forward, back).
- All icons are single-weight outline style (SF Symbols if building natively, or an equivalent consistent-weight icon set in Flutter — do not mix icon families).
- Icons are never used purely for decoration next to a label that's already self-explanatory (e.g. the current flame icon next to "Streak," clock icon next to timestamps) — remove these unless the icon replaces text rather than duplicating it.
- Icon color is always `ink-secondary` at rest; only the active tab-bar icon and a handful of primary actions use `accent-solid`.

---

## 7. Content & Copy Rules

**The rule:** a screen header (title) never needs a subtitle unless the subtitle contains information the title doesn't already imply. Right now, almost every screen in Stepsy pairs a title with a redundant descriptive subtitle underneath it — this pattern is removed everywhere. See Section 8 for the exact list per screen.

Additional copy rules:
- No backend or architecture terminology in user-facing text (e.g. "append-only," "ingestion" — these describe how the system works internally, not something a user needs to know).
- No placeholder/test content ships in any production screen — see Section 9's flagged item.
- No redundant status text where the UI already shows the status visually (e.g. an "Active" badge on the user's own account, which is always true by definition).
- Numbers and counts (points, steps) are the visual hero of their screen — the copy around them should be minimal, letting the number do the work.

---

## 8. Screen-by-Screen Redesign Notes

### Steps (Daily Movement)
- **Cut:** the separate "Balance: 0 pts" text inside the earnings row (it's already shown on the Points screen — showing it twice is redundant; keep only "Earned Today").
- **Cut:** "View Top Walkers" text next to the leaderboard row — the chevron already implies navigation.
- **Cut:** the "0% Completed" badge duplicating the progress bar directly beneath it — the bar itself is the indicator.
- **Rename:** "Step Ingestion & Conversion" → this is internal engineering language. Rename to something a user would actually understand, e.g. "Convert Steps," or reconsider whether this section should exist at all if steps convert automatically.
- **Keep:** the large step numeral, the distance/calories/remaining three-stat row, and the activity log with its segmented time filter — these patterns work, they just need the visual system applied.

### Points & Ledger
- **Cut:** the subtitle "Append-only transaction balance" entirely — rename the screen simply "Points."
- **Cut:** the "15 of 15" counter above transaction history — this reads as a debug pagination artifact, not user-facing copy.
- **Redesign:** consecutive identical "Steps Converted" rows from the same timestamp should be grouped into a single row (e.g. "Steps Converted — +80 pts") rather than five separate near-identical entries.
- **Keep:** the large balance numeral and the lifetime earned/redeemed split — good pattern, just needs the visual system applied.

### Rewards Market
- **Cut:** the subtitle "Partner Offers & Vouchers" under the title, and "Single-Use Passes" under "Active Catalog" — both are redundant with their section headers.
- **Redesign:** voucher cards keep their structure (badge, title, cost, redeem button) but move from boxy black-bordered cards to the card system in Section 5.

### Wallet
- **Cut:** the subtitle "Redeemed Promos & Passes" under "My Wallet."
- **Fix:** the current single-card layout leaves a large empty white area below it — this needs proper list/empty-state handling so it doesn't look broken when there's only one voucher (or none).
- **Keep:** the Active/Used/Expired segmented control and the visible voucher code — both are good, functional patterns (the visible code matters for the fraud-prevention model discussed for this app).

### Profile & Settings
- **Cut:** the subtitle "Account Details & Region" under the title.
- **Cut:** the "Active" badge next to the user's own email — always true, tells the user nothing.
- **Cut:** every settings-row subtitle ("Country code & step reset timezone," "Store cashier scanner & voucher redemption," "Body sensors, physical activity & battery optimization," "Revoke session on this device," "Permanently remove user data & ledger access") — the row titles alone are self-explanatory; delete all of these captions.
- **Rename:** "24/7 Step Sensors & Permissions" → this is technical phrasing for what should read as a normal iOS-style permission row, e.g. "Motion & Fitness Access."
- **Flag for product review, not just design:** "Merchant POS Terminal" appears in the general consumer profile screen. A cashier-facing tool doesn't belong in the same navigation as a regular user's personal settings — this likely needs to live in a separate merchant/staff-facing surface entirely, not a row in the consumer app's Profile tab. Confirm this with whoever owns the merchant-redemption flow before just restyling it in place.

---

## 9. Critical Flag — Not a Design Issue

The Steps screen currently has **"+1,000 Steps" and "+5,000 Steps" buttons that let a user manually add steps directly in the app.**

This is very likely a development/testing affordance that was left in, but if it ships to production it is a direct fraud vector: it lets any user fabricate step counts and convert fake activity into real points and real redeemable vouchers, undermining the entire automatic-verification model (Apple Health / Google Health Connect) this app is supposed to rely on. This needs to be removed from any production build — flagging it here explicitly because it's a functional/security issue, not something a visual redesign should just quietly restyle and leave in place.

Similarly, **"Test Offer 09b6" in the Rewards Market** is placeholder/test data — confirm the reward catalog is fully populated with real content and test entries are excluded before this ships.

---

## 10. What This Redesign Should Deliver

- All 5 screens (Steps, Points, Rewards, Wallet, Profile) rebuilt against the color, typography, navigation, and component rules above.
- A shared design-token file/theme (colors, type scale, spacing scale, corner radius values) so the system is consistent and reusable, not hand-tuned per screen.
- No new backend logic or data model changes — this is a visual and copy pass on existing functionality, except for the two items flagged in Section 9, which should be raised back to the product owner rather than resolved silently.
