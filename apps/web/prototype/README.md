# StreetMelody pastel UI prototype

Open http://127.0.0.1:5174/prototype/ after running `python3 apps/web/serve.py` from the repository root.

Independent visual prototype. Existing app entry points are unchanged. Responsive layout checked at 390px and 1280px. Search, favorite toggle/filter, playback controls, and graph period selection are implemented. Data is illustrative and favorites reset on reload. Playback uses synthesized ambient chords, not the named recordings. Google Fonts is optional; local fallback fonts work offline.

## Generated assets

Built-in image_gen was used. Assets are stored in `assets/hero.png` and `assets/cozy-room.png`.

### Hero generation prompt

Use case: stylized-concept. Asset type: wide hero illustration for pastel music dashboard. Create polished adorable tactile 3D clay animation style scene, wide 3:2 landscape: young adult woman with brown hair in messy bun, wearing lavender hoodie and chunky purple over-ear headphones, eyes gently closed enjoying music. Half-body character positioned on LEFT third, with airy empty lavender background across middle for separately overlaid UI text. Right edge has small green leafy houseplant in cream ceramic pot. Soft lilac monochrome studio background, peach warm lighting, rounded soft materials, subtle clay texture, beautiful ambient occlusion, charming premium animation film quality. Tiny floating pink musical notes near girl. No text, no letters, no UI, no watermarks. Composition character fully visible head and upper torso, bottom cropped at waist. Reference mood: cozy lavender and cream music app.

### Room generation prompt

Use case: stylized-concept. Asset type: music playlist cover art. A beautiful cozy miniature 3D clay render living room, lavender plush armchair with peach cushion on left, warm glowing cream shade floor lamp on right, small walnut table with vinyl record player on right, leafy green plant on left, sunset window and pastel pink walls, textured soft clay surfaces and tactile fabrics, warm ambient occlusion, premium animation movie quality, beautifully styled lo-fi music listening nook. Landscape 3:2 composition. No people, no text, no lettering, no watermark. Soft lavender, cream, warm amber, muted rose palette.


## Current hero replacement (2026-10-15)

The original human hero has been replaced with a newly generated mint bird walking through a pastel street, without reference images. The exact current prompt is in `../assets/pastel/hero-generation.md`. The earlier hero prompt above is retained as history only.
