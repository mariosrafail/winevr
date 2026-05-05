# WineVR

WineVR is a modular Godot 4.6 interactive wine demo. It simulates a QR-driven tasting flow, loads client-specific wine profiles, guides the user through vial inspection hotspots, then transitions into a configurable winery scene with props, zones, narrative guidance, and completion/restart flow.

## Current Flow

1. Select a wine profile from the QR simulation screen.
2. Review the intro card.
3. Inspect the vial and open required hotspots.
4. Enter the winery once required vial points are viewed.
5. Follow narrative steps through winery props, zones, or door targets.
6. Complete the tasting and optionally restart.

## Architecture

- `core/client_profile_loader.gd`: loads the registry and active client config.
- `core/experience_manager.gd`: owns high-level experience state.
- `core/narrative_manager.gd`: tracks narrative steps and completion.
- `scripts/wine_vr_experience.gd`: composes controllers and handles cross-system flow.
- `scripts/components/*`: UI controllers for QR, HUD, onboarding, narrative, mobile controls, loading, and dev overlay.
- `scripts/winery/*`: configurable winery environment, generated props, zones, movement, and door behavior.
- `clients/*/config.json`: data-driven client profiles.
- `data/client_registry.json`: list of selectable client profiles.

## Client Registry

`data/client_registry.json` lists available profiles. Each enabled entry should include:

- `client_id`: must match a folder in `clients/<client_id>/config.json`.
- `display_name`
- `wine_name`
- `region`
- `qr_id`: unique simulated QR identifier.
- `enabled`

The QR simulation screen reads this registry and loads the selected profile through `ClientProfileLoader`.

## Adding A Client

1. Add a folder under `clients/<client_id>/`.
2. Add `clients/<client_id>/config.json`.
3. Add a matching entry to `data/client_registry.json`.
4. Define `vial_settings`, `experience_settings.hotspots`, `environment_settings`, and `narrative_steps`.
5. Run the config validator before demo/export testing.

## Narrative Steps

`narrative_steps` are ordered objects with:

- `id`: unique step id.
- `title`
- `text`
- `target_type`: `free`, `hotspot`, `zone`, `prop`, or `door`.
- `target_id`: id of the referenced hotspot/zone/prop/door.
- `required`: whether the step must be completed by its target interaction before continuing.

The guide panel uses these steps for progress, hints, and Show me target highlighting.

## Environment Props And Zones

`environment_settings.props` generates lightweight winery objects such as barrels, crates, signs, tables, columns, wine glasses, bottle silhouettes, tasting cards, and wall plaques.

`environment_settings.zones` creates interactable winery points. Zone ids can be referenced by narrative steps. Door entries use `type: "door"` and are treated as door targets.

Generated props, zones, and highlight markers are rebuilt when switching clients.

### Procedural Prop Types

- `barrel`: simple cellar barrel.
- `crate`: default fallback for unknown prop types.
- `table`: tasting table with primitive legs and top.
- `sign`: flat sign board for labels or zones.
- `column`: simple stone/marker column.
- `wine_glass`: small stem, base, and transparent bowl for tasting tables.
- `bottle_silhouette`: simple bottle body, neck, and cap.
- `tasting_card`: flat note/menu card that can carry a short optional label.
- `wall_plaque`: premium wall-mounted plaque with optional label text.

Example prop config:

```json
{
  "id": "reserve_tasting_card",
  "type": "tasting_card",
  "position": [0.34, 0.72, -0.86],
  "rotation": [-8.0, -12.0, 0.0],
  "scale": [0.95, 0.95, 0.95],
  "color": "#D8C38B",
  "label": "Tasting Notes",
  "label_offset": [0.0, 0.22, 0.0],
  "visible": true
}
```

## Visual Presets

Client environments can also define lightweight procedural styling:

- `accent_color`: trim, highlight accents, and vial studio accent color.
- `secondary_light_color`: fill/rim light tint.
- `fog_enabled`: optional fog, currently only applied at `high` visual quality.
- `fog_color`
- `floor_pattern`: `stone`, `tile`, `plank`, or `smooth`.
- `wall_pattern`: `blocks`, `panels`, or `smooth`.
- `visual_quality`: `low`, `medium`, or `high`. Default is `medium`.

`low` visual quality keeps the scene mobile-safe by limiting generated decorative props and hiding optional prop labels unless a prop sets `show_label_on_low_quality: true`.

Props can optionally include:

- `label`: Label3D text shown on the prop.
- `label_color`
- `label_font_size`
- `label_offset`

These settings are procedural and mobile-friendly; no external 3D assets are required.

## Validation

Run the lightweight validator from Godot:

```powershell
godot --headless --script res://scripts/dev/validate_configs.gd
```

It checks:

- registry JSON validity
- client config JSON validity
- duplicate `client_id`
- duplicate `qr_id`
- missing profile files referenced by the registry
- narrative hotspot target ids
- narrative zone/door target ids
- narrative prop target ids
- visual quality and procedural pattern names

## Dev Controls

These are for demo testing only and are not shown in normal UI:

- `R`: reset current client experience, including viewed hotspots, narrative progress, vial view, winery view, and return to intro.
- `Esc`: return to QR/client selection.
- `F3`: toggle dev overlay with client id, state, current narrative step, active target, FPS, and input hint.
- `F6`: cycle debug viewport presets: native, desktop 16:9, mobile portrait, and tablet landscape.
- `F7`: toggle demo mode. Demo mode hides the dev overlay and keeps dev-only UI out of the recording view.
- `F8`: hide all UI temporarily for clean screenshots or B-roll.
- `F9`: restore UI after screenshot/B-roll capture.
- `F10`: reset the current camera/view for the active state.
- `1`-`9`: select registry entries from the QR simulation screen.

## Demo Viewport Test Modes

Debug runs can use `F6` to cycle layout presets without changing export settings:

- `desktop 16:9`: `1280x720`
- `mobile portrait`: `390x844`
- `tablet landscape`: `1024x768`

The active preset is shown in the optional `F3` dev overlay. Browser exports should be checked with browser/device tools instead of relying on window resizing.

## Internal QA Checklist

Before a client demo or export test:

- QR screen loads and each profile button selects the correct client.
- All three clients load without warnings that block play.
- Vial appears with the correct liquid/cap color and all required hotspots can be opened.
- `Enter Winery` stays disabled until required hotspots are viewed, then enables.
- Winery entry transition reaches the interior for each client.
- Mobile controls appear in winery mode and move/look controls respond on a touch viewport.
- Narrative `Show me` pulses the correct hotspot, zone, prop, or door without moving the camera.
- Prop labels face the camera, stay readable, and are hidden in `low` visual quality unless explicitly opted in.
- Narrative completion screen appears at the end and restart works.
- `R` resets the current client experience back to intro.
- `F3` toggles the dev overlay and shows client/state/step/target/FPS.
- `F6` cycles desktop, mobile portrait, and tablet landscape debug layouts in editor/desktop runs.
- `Esc` returns to the QR/client selection screen.
- Switching clients repeatedly does not duplicate props, zones, labels, or target markers.

## Demo Checklist Overlay Content

Use this short checklist during a guided manual run:

- QR select
- Vial hotspots
- Narrative guide
- Enter winery
- Door/props/zones
- Completion modal
- Restart

## Demo Recording Checklist

Before recording:

- Run the project once and confirm the `[WineVR][Health]` startup lines report registry loaded, enabled clients, active client, validation status, and visual quality.
- Press `F7` to enable demo mode.
- Press `F3` once to confirm the dev overlay stays hidden in demo mode.
- Use `F6` only before recording if a desktop/mobile/tablet layout needs checking.

Recording path:

- QR select: show the client profile choice.
- Intro: pause briefly on the premium wine intro.
- Vial rotate: drag the vial and show the procedural presentation.
- Hotspots: open each required tasting point.
- Narrative guide: use the guide panel and Show me once.
- Enter winery: show the unlock state and transition.
- Prop/zone interaction: inspect one winery detail.
- Completion modal: finish the narrative path.
- Restart: press Restart Experience and confirm the flow resets.

Capture helpers:

- `F8`: hide UI for clean visual shots.
- `F9`: restore UI.
- `F10`: reset the current view before a retake.

## Export Readiness

Export notes live in `exports/README.md`. Intended targets are Android, Web, and Windows desktop demo. Generated builds should not be committed.

## Web Demo Hosting

The static landing page in the repository root loads the Godot Web export from `web5/WineVR.html`. The export files use relative paths, so keep the full `web5/` folder structure unchanged.

Local test:

```powershell
python -m http.server 8000
```

Open:

```text
http://localhost:8000/
```

Use a local server for testing. Do not open `index.html` or `web5/WineVR.html` directly from the filesystem, because browser security rules can block the Godot export files.

Netlify settings:

```text
Build command:
Publish directory: .
```

The `netlify.toml` file defines the required headers for Godot Web assets, including `application/wasm` for `.wasm`, `application/octet-stream` for `.pck`, `application/javascript` for `.js`, no-cache for HTML, and immutable caching for export binaries/scripts.

## Current Limitations

- QR scanning is simulated.
- No backend or remote profile loading.
- No real AR/VR runtime integration yet.
- Winery environments are generated from lightweight primitives.
- Validation is structural and reference-based; it does not replace a runtime playthrough.
