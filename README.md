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

`environment_settings.props` generates lightweight winery objects such as barrels, crates, signs, tables, and columns.

`environment_settings.zones` creates interactable winery points. Zone ids can be referenced by narrative steps. Door entries use `type: "door"` and are treated as door targets.

Generated props, zones, and highlight markers are rebuilt when switching clients.

## Visual Presets

Client environments can also define lightweight procedural styling:

- `accent_color`: trim, highlight accents, and vial studio accent color.
- `secondary_light_color`: fill/rim light tint.
- `fog_enabled`: optional fog, currently only applied at `high` visual quality.
- `fog_color`
- `floor_pattern`: `stone`, `tile`, `plank`, or `smooth`.
- `wall_pattern`: `blocks`, `panels`, or `smooth`.
- `visual_quality`: `low`, `medium`, or `high`. Default is `medium`.

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
- `1`-`9`: select registry entries from the QR simulation screen.

## Internal QA Checklist

Before a client demo or export test:

- QR screen loads and each profile button selects the correct client.
- All three clients load without warnings that block play.
- Vial appears with the correct liquid/cap color and all required hotspots can be opened.
- `Enter Winery` stays disabled until required hotspots are viewed, then enables.
- Winery entry transition reaches the interior for each client.
- Mobile controls appear in winery mode and move/look controls respond on a touch viewport.
- Narrative `Show me` pulses the correct hotspot, zone, prop, or door without moving the camera.
- Narrative completion screen appears at the end and restart works.
- `R` resets the current client experience back to intro.
- `F3` toggles the dev overlay and shows client/state/step/target/FPS.
- `Esc` returns to the QR/client selection screen.
- Switching clients repeatedly does not duplicate props, zones, labels, or target markers.

## Export Readiness

Export notes live in `exports/README.md`. Intended targets are Android, Web, and Windows desktop demo. Generated builds should not be committed.

## Current Limitations

- QR scanning is simulated.
- No backend or remote profile loading.
- No real AR/VR runtime integration yet.
- Winery environments are generated from lightweight primitives.
- Validation is structural and reference-based; it does not replace a runtime playthrough.
