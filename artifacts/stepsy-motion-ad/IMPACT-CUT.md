# Stepsy · Impact cut

This revision answers the request for a stronger landing, more motion graphics, directed close-ups and less reading. It replaces the full-page journey with six focused visual moments. The original 22-second ad remains available separately.

**Format:** portrait 1080 × 1920. **Duration:** 20.625 seconds. **Beat grid:** 128 BPM. No voiceover; Roman Urdu captions accompany the visual actions.

| Time | Visual direction |
| --- | --- |
| 0–2.344 | Oversized masked Stepsy reveal, falling footprint slam at 0.234 s, short camera shake, expanding rings and a fast walking-film iris. “Qadam wahi. Faida naya.” lands in two moving lines. |
| 2.344–5.625 | A phone rises into view; the camera pushes into live steps, pulls back and follows it into a pocket. Tracking-on confirmation pops forward. |
| 5.625–8.438 | Coins travel from eligible steps into the points balance. The camera follows them into a large 133-point result. |
| 8.438–12.188 | A reward ticket springs forward. Separate close-ups show the 20% example and the redeem action. A confirmation burst marks the claim. |
| 12.188–15.469 | The ticket flips into Wallet. A controlled QR close-up and scan guide demonstrate showing the voucher at a store. |
| 15.469–20.625 | Walk → Points → Discounts icons converge into the brand. The character waves over the centred Android coming-soon card. |

Carried circular shapes reveal scenes on the beat. The palette stays cream, sage, forest and warm gold. Camera moves apply to the product objects while the short captions remain stable. Soft edge masks prevent abrupt clipping during close-ups. The technical HUD from the high-energy skill is deliberately omitted to suit Stepsy's cozy identity.

## Files

- `impact.js`: deterministic animation, cue list and original synthesised music/contact sounds.
- `Stepsy-sage-editable.html` in `artifacts/stepsy-motion-ad/`: current self-contained browser preview with playback and scrubbing, the stronger opening and the sage logo.
- `Stepsy-impact-review-v2.mp4`: 30-fps review version.
- `Stepsy-impact-sage-1080x1920.mp4`: current 60-fps export, four temporal samples per frame.
- `Stepsy-impact-sage-1080x1920_silent.mp4`: matching picture without sound.
- `impact-verification.json`: font loading, random-access rendering and pixel-based closing-card centring checks.

Rebuild using `build_ad.py --composition impact.js --name Stepsy-sage-editable.html --logo design/brand/Stepsy-mark-sage.png`, then use `render.mjs` with the new HTML and output filename. Dependencies, explicit executable flags and cache layout are described in README.md. Use a separate HTML filename when an earlier file is memory-mapped by a running Windows browser.

## Placeholders and sources

The user-supplied `Walk.mp4` is visible in the opening; the original footage is unchanged. Existing Stepsy trail and companion artwork are reused. The logo is the sage imagegen colour variant in `design/brand/Stepsy-mark-sage.png`; its original is preserved. The packer also embeds the earlier jogging frames for editing, although this cut does not display them.

The café, 20% discount, points totals and QR remain illustrative. The offer is marked EXAMPLE OFFER and the voucher DEMO ONLY. There are no third-party merchant logos or claims of confirmed partnerships. Points are earned from eligible steps after sync; they are not money. The Android CTA remains “Coming soon”.

Music and sweeps/contact sounds are original code synthesis, not sampled commercial recordings. The motion approach and renderer are adapted from Barty-Bart/motion-graphics under MIT; the licence and Nunito's OFL are included in the delivery folder.

Suggested review points: opening impact at 0.234 s; step-count punch-in at 3.5 s; coin transfer at 7.0 s; redeem press at 10.78 s; Wallet/QR close-up at 14.2 s. Creative appeal still needs the owner's judgement; automated checks verify rendering and encoding only.
