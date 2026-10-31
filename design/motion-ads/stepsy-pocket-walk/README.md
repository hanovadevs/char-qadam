# Stepsy · Qadam aapke. Faida bhi aapka.

A 22-second portrait motion ad in Stepsy's cream, sage and forest palette. One footprint travels through everyday walking, background tracking, synced points, a reward and a Wallet voucher. The camera reveals the full journey before settling on a centred brand card.

## Delivery

Generated files live in `artifacts/stepsy-motion-ad/`:

- `Stepsy-ad-1080x1920.mp4`: 1080 × 1920, 60 fps, H.264, stereo AAC at 48 kHz. Four temporal samples per frame smooth fast camera moves.
- `Stepsy-ad-1080x1920_silent.mp4`: the same picture without sound.
- `Stepsy-ad-editable.html`: self-contained composition with embedded imagery and Nunito; open it in a browser to play or scrub, including music.
- `alignment-check.jpg`: closing-card framing review.

The older `Stepsy-ad-review-1080x1920.mp4` is the superseded 30-second review, not the final cut.

## Beat sheet

| Seconds | Picture | Sound |
| --- | --- | --- |
| 0–2.5 | Supplied walking and jogging clips | Footstep notes and light groove |
| 2.5–5.8 | Phone, tracking control, pocket | Tracking contact click |
| 5.8–8.8 | Eligible steps sync; points rise to 133 | Rising chimes |
| 8.8–12.3 | Example café offer, 100-point claim | Button contact notes |
| 12.3–15.6 | Voucher enters Wallet; demo QR | Voucher pop/chime |
| 15.6–18.2 | Whole-course camera reveal and dive | Lift into brand signature |
| 18.2–22 | Centred Stepsy end card | Three notes; music fades out |

There is no voiceover. Short Roman Urdu headings and English product UI carry the message over an original, programmatically synthesised 124-BPM soundtrack.

## Truthful placeholders

The café, 20% offer, totals and voucher are illustrative. The offer says EXAMPLE OFFER; the QR says DEMO ONLY and is not redeemable. No third-party brand partnership is implied. Replace the sample offer with an approved live merchant offer before making a merchant-specific campaign.

The CTA says **Coming soon on Android**. Change it only after the public listing exists. Tracking requires permissions and platform background settings; point earning and partner terms apply.

## Edit and rebuild

`composition.js` owns layout, camera anchors, timing and synthesised audio. `window.seek(t)` renders any timestamp independently. The 22-second export retimes a 30-second internal choreography; use the `pacing` array to adjust tempo without breaking contact sounds. The closing camera uses the fixed brand anchor so it cannot drift toward the footprint.

`build_ad.py` embeds app-owned artwork and cached footage into the HTML. It requires Python with `fonttools`, Brotli and the existing app assets. Tool dependencies and frame caches are kept under the ignored `mobile/build/stepsy-ad-tools/` and `mobile/build/stepsy-ad-cache/` directories.

Prepare JPEG frames from the supplied originals with FFmpeg. The builder expects `Walk/frame-001.jpg` onwards and `jogging/frame-001.jpg` onwards inside the cache. Select 4.3 seconds from Walk starting at 2 seconds, at 30 fps and approximately 960-pixel width; select 4.3 seconds from jogging starting at 0.4 seconds, at 25 fps and approximately 960-pixel width. The source clips remain unchanged.

```powershell
& backend/.venv/Scripts/python.exe design/motion-ads/stepsy-pocket-walk/build_ad.py
node design/motion-ads/stepsy-pocket-walk/render.mjs artifacts/stepsy-motion-ad/Stepsy-ad-editable.html artifacts/stepsy-motion-ad/Stepsy-ad-1080x1920.mp4 --fps 60 --subframes 4 --workers 4
```

The renderer requires FFmpeg and Playwright with Chromium. If they are not on the standard paths, provide `--ffmpeg <ffmpeg.exe> --playwright <playwright-module-directory> --browser <chromium.exe>`. It stores intermediates in the ignored cache and does not delete source files. Render only one job per cache at a time, or pass a separate `--cache` directory.

For framing review, replace video flags with `--stills 1,4.1,7.8,10.3,14.3,16.9,20.2` and give the output a `.jpg` extension. Inspect the sheet before re-exporting.

## Sources and licences

- Supplied footage: `C:/Users/Ali Haider/Videos/Walk.mp4` and `jogging.mp4`, used at the user's request. No stock-footage licence is asserted; confirm distribution rights before paid placement.
- Stepsy logo, companion and trail: existing project assets, used at the owner's request.
- Nunito: SIL Open Font License 1.1, copied as `Nunito-OFL.txt` in the delivery folder.
- Rendering approach adapted from Barty-Bart/motion-graphics, MIT licence; notice copied as `Barty-Bart-motion-graphics.LICENSE` in the delivery folder.
- Music and contact sounds: original deterministic synthesis in `composition.js`; no external recording used.

No app, API, account data or deployment is changed by this ad project.
