# Export Targets

This folder is reserved for export notes only. Do not commit generated builds or platform packages here.

Intended demo targets:

## Android Demo

- Touch-first build for phones/tablets and future headset-adjacent testing.
- Use the mobile-safe visual profile first: `visual_quality: "low"` or `"medium"`.
- Verify portrait touch layout and winery movement controls before sharing an APK/AAB.
- Keep package outputs outside source control.

## Web Demo

- Lightweight browser demo for quick stakeholder review.
- Prefer compressed export output and test in a clean browser session.
- Avoid relying on local debug window resizing in browser builds; use browser/device tools for viewport checks.
- Do not commit generated `.wasm`, `.pck`, `.js`, `.html`, or export folders.

## Windows Desktop Demo

- Primary local demo build for client walkthroughs and QA.
- Best target for live guided testing with keyboard/mouse and debug shortcuts.
- Use F6 in the editor/debug run to cycle desktop/mobile/tablet viewport presets before export.
- Do not commit `.exe`, `.pck`, or generated desktop export folders.

Recommended practice:

- Export builds into a local folder outside the repository, or into `exports/local/` if that path is ignored before use.
- Keep export presets in `export_presets.cfg`.
- Commit source, config, and documentation only. Do not commit `.exe`, `.pck`, `.apk`, `.aab`, `.wasm`, or generated web export folders.

Suggested preset names when creating `export_presets.cfg`:

- `Android Demo`
- `Web Demo`
- `Windows Desktop Demo`

Do not commit exported builds. Only commit the project source, configs, docs, and export preset metadata when it is intentionally ready to share.
