# Export Targets

This folder is reserved for export notes only. Do not commit generated builds or platform packages here.

Intended demo targets:

- Android: touch-first demo build for phones/tablets and future headset-adjacent testing.
- Web: lightweight browser demo for quick stakeholder review.
- Windows desktop demo: primary local demo build for client walkthroughs and QA.

Recommended practice:

- Export builds into a local folder outside the repository, or into `exports/local/` if that path is ignored before use.
- Keep export presets in `export_presets.cfg`.
- Commit source, config, and documentation only. Do not commit `.exe`, `.pck`, `.apk`, `.aab`, `.wasm`, or generated web export folders.
