# Grape museum

The main menu's **Συλλογή σταφυλιών** button enters the museum through the existing
WineVR game state, camera, movement and interaction systems. The navigation bar connects the collection, Dafnes terrace, cellar and wine catalog. The two older vineyard showcase instances are replaced
in `WineryInterior.tscn`.

## Desktop controls

- WASD: walk; the player capsule collides with the walls and exhibit plinths.
- Mouse: look. Mouse capture starts when entering from the museum menu button.
- E: bring the actual bunch close to the camera; its profile bars appear only then.
- E or Esc during inspection: return the bunch to its original hook and hide the bars.
- Hold left mouse on a berry and drag: test individual picking. A small pull bends
  its stem; a sustained pull beyond 4.5 cm (scaled for larger fruit) detaches it.
  Keep holding to move the loose berry, release to drop it, and click to pick it
  up again. The wheel changes its distance while held. Available on desktop.
  The visible hand reaches the selected berry, closes thumb and index on opposing
  surface contacts, then pulls. The remaining fingers curl out of the way. The
  wrist follows the physical berry across detachment; release opens the pinch
  before the arm returns. Skin-triangle queries fit the initial two contacts.
  Contact fitting also samples the skinned fingertip surfaces, including their
  thickness, as the fingers close and while holding detached fruit. The pedicel
  yields by up to 26 mm, stiffens and holds for 0.30 seconds of sustained tension
  before releasing; easing off unloads it. Idle bunch motion cannot sever fruit.
- While holding a detached berry, hold right mouse and drag to roll the fruit
  between thumb and index without moving the wrist's target. The fingertips
  refit to the rotating surface. Release right mouse to stop rolling.
- While holding detached fruit, wheel up brings it closer, wheel down moves it
  away. The approach is smoothed and preserves screen framing; fingers and arm
  follow the physical berry. Left-button release still drops it normally.
- Shift + hold left mouse and drag: grasp the whole bunch with the anatomical hand,
  both while it hangs and during close inspection. Release to let go.
- T: restore all detached berries and remove loose fruit for another test.
- During inspection: hold right mouse and drag to rotate; wheel to zoom;
  left/right arrows apply rotation torque. Click the panel's left/reset/right buttons.
- Options always releases the mouse cursor, including while inspecting.
- The Options header has an immediate Fullscreen/Windowed button; F11 also toggles it.
- Esc outside inspection: main menu. Resume restores mouse capture.
  Tab releases/captures mouse look outside inspection.

Each bunch is a `RigidBody3D` suspended by a `PinJoint3D` at the actual stem cut point.
Gravity and hand forces produce its swing; its stem remains pinned. Inspect briefly
freezes the body for the transition, releases the pin and uses a damped spring to
hold the same body near the camera. Mouse picking uses the physical bunch collider.
Opening Options pauses grasping and keeps the inspection cursor available.

Each of the 403 berries has a short, damped stem spring and a spherical contact
shape instead of one capsule around the whole bunch. Acceleration, rotation and
local grasp load produce bounded secondary motion; release lets it settle.
The spring approximation keeps berries attached except during explicit individual
picking. Detachment is a test threshold, not a measured botanical breaking force;
there is no juice simulation. GPU skinning retains original materials and surface
count. `BerryPhysicsQA.tscn` checks response/settling at 30, 60 and 120 Hz and
opens station panels with E, then closes them with actual GUI pointer events.
`BerryPluckQA.tscn` checks pointer selection, gentle pulls, single-berry detachment,
authored geometry/material preservation, gravity, re-grabbing and reset for all
three varieties. Loose berries live in the museum branch and are suspended when
that branch is inactive.

The procedural Vidiano retains 73 independent berries, with a wider size range,
smaller fruit towards the tip, irregular spacing/tilt and varied green-gold skin.
It remains an educational illustration, rather than a botanical scan.

Exploration pauses mouse look while a panel is open and resumes it on close.
The active modal's canvas is raised above the other UI canvases so its buttons
receive clicks, including the winery info panel on its separate CanvasLayer.

The hand has continuous skinned geometry, sixteen bones, short fingernails and baked
2K skin albedo/normal maps. Each finger solves a separate contact-limited curl against
an envelope measured from the actual bunch mesh; the thumb uses an opposing IK pose.
The wrist follows the fruit body while dragging and all digits open smoothly on release.
The profiles are prepared on room creation and the grip is solved once per grasp, so
the mesh sampling and collision search are not repeated every rendered frame.

The original hand is authored locally, with no downloaded hand assets. Rebuild its
editable `blender_models/museum_hand.blend`, game GLB and rig metadata with Blender:

```powershell
blender --background --factory-startup --disable-autoexec --python tools/build_museum_hand.py
```

## Display values

`data/grape_museum.json` contains the five labels, colors and values for each variety.
All values are currently **illustrative normalized scores from 0 to 100**. A bar
showing `82 / 100` is a relative teaching score, **not 82% sugar by mass**. Every profile
explains this. The values are not taken from the cited scientific papers. No laboratory analysis is claimed.

Replace values and the note with a properly sourced analysis when available; physical
measurements should retain their real units and define the scale used for bar lengths.

## Authored assets

- Editable corrected Blender originals: `blender_models/liatiko_bunch.blend` and
  `blender_models/kotsifali_bunch.blend`.
- Game assets: `assets/models/grape_museum/*_bunch.glb`.
- `asset_report.json` records triangle counts and export anchors.
- Each GLB has one joined mesh with ten material surfaces. Six baked skin variants
  preserve color, roughness and normal detail. Leaf color and normal maps are baked.
- The glTF root is the actual stem cut point, not the bunch center. All rotation/sway
  occurs about that anchor so the suspension remains connected.
- Every mesh uses a common `UVMap` layer before joining, including the leaf.
- `.gdignore` keeps the Blender originals out of Godot's automatic Blender import.

Re-export using Blender:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --disable-autoexec --python tools/export_grape_museum.py
```

Append `-- --rebake` after editing source geometry/materials to refresh the texture
cache. Without that flag the existing baked maps are reused.

## Validation

Run the real game integration checks with Godot 4.6.1 stable:

```powershell
godot --headless --path . res://scenes/dev/GrapeMuseumQA.tscn
```

To capture rendered views on the GPU:

```powershell
godot --path . res://scenes/dev/GrapeMuseumQA.tscn -- --museum-capture
```

The tests use the main-menu button and actual game interaction ray, verify all three varieties,
hidden/revealed world-space bars, physics swings, stem constraints, close inspection,
mouse grasp/drag/release, rotation/reset, walking, collision and modal input handling.
The rendered GPU run additionally checks native fullscreen/windowed transitions,
cursor capture and the Options panel's size. The headless run dispatches mouse events
directly to the physics handler because its dummy window cannot provide native input.
Screenshots/logs are stored in the ignored `work/` folder. For a direct game preview:

```powershell
godot --path . -- --grape-museum
```

The Windows build is refreshed in `build/WineVR.exe` with its adjacent `WineVR.pck`.
The `data/` folder must remain exportable; its previous `.gdignore` prevented both the
client registry and museum data from reaching the exported game. The Windows preset
also includes the older landscape/tree raw GLBs required by their runtime loaders.
The packaged PCK passed the integration checks, and the release executable passed
its own startup/museum-entry smoke test.

## Berry spacing and contacts

The red bunches use prepacked `.scn` copies of the original GLB geometry, built
with `tools/pack_grape_contacts.gd` and `scripts/winery/grape_bunch_spacing.gd`.
Each intact berry is translated as a whole; its UVs, normals and skin shape are
preserved. Ellipsoids enclose every authored vertex. Pair separation retains at
least 1.5 mm between those bounds at rest, and nearby pedicel vertices follow
the corrected fruit positions. The original Blender/GLB sources stay editable.
`assets/models/grape_museum/spacing_report.json` records the measured clearances.
Both red models now use the same strict moving contact constraints as Vidiano.
`GrapeContactsQA.tscn` checks all three models, including every visible vertex,
rest clearance and motion/contact loads at 30/60/120 Hz. Contact orientations are
cached once per step, and solver iterations stop when the constraints are met.
The standalone demo's horizontal mouse rotation is inverted on all three bunches;
vertical dragging still cannot tilt them.

## Natural red grape skins

Liatiko and Kotsifali retain their original Blender geometry, UVs and independent
berry rigs, with separate generated seamless albedo textures in
`assets/textures/grape_museum/`. `red_grape_skin.gdshader` adds subtle skin relief,
variable wax roughness and restrained reflections, with offset/tint variation
across the original fruit material groups. Leaf and stem materials are preserved.
Full generation prompts and provenance are in `red_grape_skin_source.txt` beside
the maps. Native demo QA and the berry spring regression both pass.

## Vidiano, anatomy and touch

Vidiano is an original procedural teaching model with joined berry geometry, skin shading and the authored leaf texture. Its fruit material uses an original generated seamless albedo map (`assets/textures/grape_museum/vidiano_skin_albedo.png`), with per-berry UV offsets, wax-dependent roughness, subtle surface relief and restrained backlighting. Source and full image-generation prompt are recorded beside the map in `vidiano_skin_source.txt`. Its 73 varied ellipsoids are packed with separating-plane constraints before skin and pedicel meshes are built. Resting skins keep at least 1.5 mm clearance; moving contacts use the complete visible ellipsoids, including stem bending, rather than the smaller picking spheres. `VidianoContactsQA.tscn` checks every pair under rotation and contact loads at 30/60/120 Hz and captures four viewing angles. It is not a botanical scan. Existing Liatiko and Kotsifali Blender originals remain editable.

Four profile pages cover the comparative scores, skin/pulp/seeds, ripening and a 3D cutaway. The cutaway highlights each part through world-space buttons. Total acidity, soluble solids and phenolics have separate definitions; the interface does not infer measurements from appearance.

Portrait touch inspection replaces the offscreen world panel with a native scrolling sheet. Its cutaway has an isolated viewport so it can be explored without steering the main scene. Rotating into landscape restores the world panel. Leaving a scene releases grasping, returns the bunch and disables hidden colliders.

## XR scope

See [XR compatibility](xr_compatibility.md) for native OpenXR, browser WebXR, fallback selection, safe teleportation and AR session handling. The world-space exhibit controls share the desktop interaction protocol. Simulated lifecycle and physics tests do not substitute for device testing. AR currently presents the collection relative to the tracked origin; it does not claim surface hit testing or physical sample recognition.

## Landscape material attribution

The vineyard uses the CC0 **Rocky Terrain 02** material by Amal Kumar, from Poly Haven. Local provenance and file checksums are in `assets/textures/cretan_terrain/source.json`. This material is a visual surface, not evidence of the geology at a particular geographic location.

## Longitudinal berry cutaway references

The fourth tab now shows a shaped half-berry with a thin textured skin rim,
a recessed wet mesocarp surface and two visible pear-shaped seeds with a
pointed beak and subtle testa grooves. The two exposed seeds illustrate one
longitudinal section; they are not a fixed seed count for the three cultivars.
Peripheral strands follow the skin and axial strands continue from the pedicel
to the seed locules. Red skin surrounds pale flesh in the red models as well.
The flesh material is original generated artwork, with its complete prompt and
provenance in `assets/textures/grape_museum/grape_pulp_source.txt`.

Anatomical references reviewed online:

- [Vascular Connections Into the Grape Berry (Frontiers, 2021)](https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2021.662433/full): central/peripheral/ovular vasculature, brush zone and micro-CT longitudinal view.
- [Bondada & Keller (WSU, 2012), figure 1](https://file.scirp.org/Html/6-2600383_20717.htm): healthy berry longitudinal photographs showing hydrated translucent mesocarp and seeds in central locules.

The model is a qualitative educational reconstruction, not a scan or measured
cultivar specimen. `BerryAnatomyQA.tscn` verifies all three fourth-tab views,
recessed geometry, skin textures, pointer selection and cleanup.
