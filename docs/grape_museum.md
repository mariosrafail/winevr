# Grape museum

The main menu's **Αίθουσα σταφυλιών** button enters the museum through the existing
WineVR game state, camera, movement and interaction systems. Normal winery entry
also displays the new room. The two older vineyard showcase instances are replaced
in `WineryInterior.tscn`.

## Desktop controls

- WASD: walk; the player capsule collides with the walls and exhibit plinths.
- Mouse: look. Mouse capture starts when entering from the museum menu button.
- E: bring the actual bunch close to the camera; its profile bars appear only then.
- E or Esc during inspection: return the bunch to its original hook and hide the bars.
- Hold left mouse and drag: grasp and pull a bunch with the articulated anatomical hand,
  both while it hangs and during close inspection. Release to let go.
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

`data/grape_museum.json` contains the four labels, colors and values for each variety.
All values are currently **illustrative normalized scores from 0 to 100**. A bar
showing 82% means 82% of that display scale, **not 82% sugar by mass**. Both panels
explicitly explain this. No laboratory analysis is claimed.

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

Run the real game integration checks with Godot 4.7.2:

```powershell
godot --headless --path . res://scenes/dev/GrapeMuseumQA.tscn
```

To capture rendered views on the GPU:

```powershell
godot --path . res://scenes/dev/GrapeMuseumQA.tscn -- --museum-capture
```

The tests use the main-menu button and actual game interaction ray, verify both models,
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

## XR scope

The current delivery is desktop-first, as requested. Models, supports, panels, bars
and inspection buttons are world-space 3D nodes. Interaction uses the existing
`Interactable` protocol and collision layer 1; the room provides a teleport floor on
layer 8. The hand uses collision layer 16 and fruit bodies layer 4. Both hands
follow the existing XR controllers when XR is active, and the right controller's
grip/squeeze action drives the same physics grasp. These bindings require headset
validation and action-map tuning on the target runtime.

Native headset action maps, Quest vendor passthrough, browser AR sessions, real-world
placement and device testing are a later implementation step. This delivery does not
claim AR/VR device validation.
