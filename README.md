# Grapes of Crete

Grapes of Crete is a Godot 4.6.1 experience about the grapes, landscape and wine of Crete. Its Greek interface connects a physical grape collection, an artistic Dafnes vineyard, a four-stop cellar tour and a guided tasting catalog.

## Current experience

- **Collection:** Liatiko, Kotsifali and Vidiano. Suspended fruit responds to physical grasping, rotation and close inspection. Four information pages cover comparative profiles, berry anatomy, ripening and an interactive 3D cutaway.
- **Dafnes:** a walkable terrace overlooking vines and Cretan-inspired hills, four educational stations and a Crete map. The scene is an artistic representation, not surveyed terrain or a real winery.
- **Cellar:** harvest, fermentation, oak maturation and tasting stations, with barrels, steel tanks and wine glasses. Tasting completion leads here; the menu also allows direct exploration.
- **Wines:** searchable catalog with region filters, three clearly labeled educational Cretan profiles and the existing client profiles. Required hotspots gate the cellar step; optional steps can be skipped.
- **Touch:** movement/look controls, rotation and a portrait inspection sheet with readable information and its own 3D cutaway.
- **XR:** native OpenXR and browser WebXR lifecycles, controller/gaze selection, snap turn, validated teleportation, world-space navigation and conditional AR. Availability is detected at runtime. See [XR compatibility and device validation](docs/xr_compatibility.md).

The five profile scores are **illustrative 0–100 comparisons**, not laboratory readings or percentages of sugar. Total acidity and pH are different quantities. Source references and explanatory notes are included in the data. No infrared measurement, invisible marker detection or universal device compatibility is claimed.

## Run

Open `project.godot` with Godot **4.6.1 stable**, or run:

```powershell
godot --path . --xr-mode off
```

For the Windows application, keep `build/WineVR.exe` beside `build/WineVR.pck`. The local web launcher is `index.html`; serve the repository over HTTP on localhost and open the address. WebXR on other hosts requires HTTPS and a compatible headset/browser. The launcher detects a missing export and explains how to recover. It does not publish automatically.

WASD moves, the mouse looks, E inspects/returns, Esc opens the menu, and F11 toggles fullscreen. On desktop, hold left mouse on a berry and pull to detach it for testing; keep holding and use right-drag to roll it between the fingers, or the wheel to bring it closer/away. Release left mouse to drop it and T to restore all fruit. Shift + left mouse grasps the whole bunch. During inspection, right mouse rotates and the wheel zooms; C cycles information pages. Touch controls appear on touch devices. See [museum controls and assets](docs/grape_museum.md) and [local export targets](exports/README.md).

## Standalone grape-room demo

The standalone **Grape Room Demo** export opens `scenes/GrapeRoomDemo.tscn`
with display settings above its startup menu, then enters only the museum room
and its three grape exhibits. It creates no hands or picking interactions.
E brings the bunch forward into a screen inspection overlay with the original
charts, then returns it to its suspension. A separate transparent viewport keeps
the bunch and charts in front of the room. The mesh center stays fixed
on screen and the bunch remains upright relative to the viewer, even when the
camera is tilted. Entry and return follow an eased 0.65-second flight; the
foreground projection remains active through the return. The right panel has
three larger tabs with animated hover, selection and page changes, plus a
Return button. Left mouse dragging shows a hand cursor and rotates around
the screen's vertical axis with
the requested inverted horizontal direction. All three bunches use separated
rest geometry and contacts enclosing their visible skins,
with individual berry inertia,
stem bending and neighboring fruit contacts. Escape pauses and F11 changes
fullscreen. The room demo uses a 1.65 m/s walking pace with acceleration and
braking, gently smoothed mouse look, and a small distance-driven camera sway
that settles at rest and stops during inspection. Larger explanatory text and
a centered hand/E prompt make the exhibits easier to read and discover.
The export embeds its package in
`build/grape-room-demo/Grapes-of-Crete.exe` so that executable can be copied
on its own. This demo is built with `--export-debug "Grape Room Demo"`: the Windows
debug runtime starts correctly on the tested GT 730 system, whereas the release
runtime stalled during graphics initialization. The full application remains a
separate export. Native room QA and the packaged demo's first rendered frame
were verified.

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

The catalog uses WineDatabase profiles first, with this registry as a fallback. The Cretan educational collection is appended without replacing client profiles.

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
- `Esc`: close inspection or open the main menu.
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

## Export and local browser preview

See [export targets](exports/README.md) for Windows, Linux, macOS, Web, Android Touch and the separately configured Android OpenXR target. Generated packages remain local. `tools/export_local.ps1` builds desktop/Web targets with the matching Godot 4.6.1 templates.

The root landing page loads `exports/local/web/WineVR.html`. Serve the repository, for example:

```powershell
python -m http.server 8765 --bind 127.0.0.1
```

Open `http://127.0.0.1:8765/`. Do not open the HTML directly from the filesystem. Keep every generated Web file together. `netlify.toml` sets MIME types and revalidation for unversioned exports; a source-only deployment has no generated Web build. No deployment is performed by local export.

## Runtime checks

The development scenes exercise the actual application, state transitions and input paths:

- `GrapeMuseumQA.tscn`: suspended fruit, close inspection, grabbing, rotation, hand geometry and cutaway cleanup.
- `CretanExperienceQA.tscn`: collection/vineyard/cellar/catalog transitions, bounds, touch actions and portrait inspection.
- `TastingContentQA.tscn`: all six profiles, hotspot progression, optional steps, completion and responsive annotations.
- `ResponsiveUIQA.tscn`: menu, options, controls, catalog and navigation from 320×568 to 1440×900.
- `SampleCodeQA.tscn`: exact code lookup, duplicates/unknown input and real Enter-to-profile selection.
- `XRIntegrationQA.tscn` and `scripts/vr/tests/validate_xr.gd`: simulated XR lifecycle, active rays, controller fallback, teleport physics, AR restoration and focus/modal gates.

Run a development scene with `godot --headless --xr-mode off --path . res://scenes/dev/<scene>.tscn`; native rendering tests omit `--headless`. Screenshots and reports go to the ignored `work/` folder. Simulation cannot establish performance or compatibility on an untested physical headset.

## Scope and next hardware validation

- Wine selection uses local configured profiles and [sample codes](docs/sample_recognition.md), without a backend or camera recognition.
- OpenXR/WebXR are implemented; availability still depends on the device, browser and active runtime.
- Android native OpenXR needs its build template/toolchain completed. Android Touch is a separate debug package.
- The 3D spaces and anatomy are educational representations. Scores are illustrative; no sensor, spectroscopy or laboratory inference is performed.
- AR has no surface hit testing, persistent anchors or room reconstruction. Physical headset/phone validation remains required.
