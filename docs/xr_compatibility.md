# WineVR XR compatibility and checks

WineVR uses one Godot 4.6 project for desktop, WebXR and native OpenXR. The mode selector reports what the current runtime actually supports. A platform name is never treated as proof of VR or AR support. A missing headset, declined browser permission or ended session restores desktop controls.

| Route | Implemented path | Required environment | Validation here |
| --- | --- | --- | --- |
| Windows / Linux PC VR | OpenXR stereo rendering, tracked aim/grip, haptics, teleport, snap turning | Connected headset and active OpenXR runtime before WineVR starts | Script/lifecycle/physics simulation; real headset still required |
| Android standalone headset | ARM64 OpenXR export preset, Compatibility renderer, shared controller actions | Android SDK/JDK, installed Godot Android build template, compatible headset/runtime | Export attempted; missing project build template prevents APK creation. Device testing still required |
| Android phone/tablet | Separate ARM64 touch APK, Compatibility renderer, OpenXR disabled | Android 7.0+ with OpenGL ES 3 | Debug APK exported and signature verified; no connected Android device available for runtime testing |
| Browser VR | WebXR `immersive-vr`, optional floor/hand tracking, select events | HTTPS or localhost, WebGL 2, browser and device reporting support, direct user button press | Capability/lifecycle logic and rig simulation; browser/device acceptance still required |
| Browser AR | WebXR `immersive-ar`, transparent viewport, collection presentation | Browser and device explicitly reporting immersive AR support | Logic and scene-presentation checks; real passthrough still required |
| Native headset AR | OpenXR alpha blend or additive display when reported | Compatible runtime; vendor extension/plugin may be necessary | Blend selection logic; real passthrough still required |
| macOS desktop / ordinary browsers / touch devices | Standard 3D experience | Compatible graphics driver/browser | Desktop fallback; no universal XR promise |

The macOS preset is an unsigned universal desktop package. It does not add native visionOS or ARKit support. An iPhone, iPad or headset browser only offers immersive modes if its actual WebXR runtime reports them; otherwise WineVR remains usable as a touch/desktop experience.

## Native initialization

`project.godot` enables OpenXR and stereo shaders at startup, keeps the Mobile renderer on desktop, and selects Compatibility for web and mobile exports. The Android Touch preset disables OpenXR with a custom feature override. Android's explicit `rendering_method.mobile` setting also ensures its manifest does not require Vulkan hardware. Headset startup failures do not show a blocking engine alert. `scripts/vr/openxr_action_map.tres` is an explicit Godot 4.6 default action map, including Khronos simple controllers, Touch, Index, Vive, Pico, WMR and the EXT hand interaction profile. The runtime remains responsible for matching and remapping these bindings.

OpenXR hand tracking and hand interaction extensions are requested when the runtime supports them. WineVR's visible hands use controller/grip tracking and an authored grasp animation; this is not a claim of a fully articulated skeletal hand-tracking implementation.

Godot 4.6 can target many Android XR devices without the vendor plugin. The OpenXR Vendors plugin remains recommended for vendor features and may be required for passthrough, store publishing or device-specific settings. The generic Android preset does not silently install it or promise these capabilities. Install the Android build template before using its Gradle export, then test each intended device. [Godot Android XR deployment](https://docs.godotengine.org/en/4.6/tutorials/xr/deploying_to_android.html)

The local Android Touch debug export uses the already-installed JBR and existing Android debug key. Godot's temporary Java-path setting was restored after export; no SDK or signing identity was installed. The OpenXR attempt stops with `Android build template not installed in the project`. The installed 4.6.1 Gradle template additionally expects Android API 35, build-tools 35.0.1 and Gradle 8.11.1; this workstation currently has API 36/36.1, build-tools 35.0.0/36.1.0/37.0.0 and a different cached Gradle version. The prebuilt touch template has no OpenXR loader and is deliberately not presented as a headset APK. Godot's OpenXR exporter requires Gradle and adds its loader dependency there. [Godot 4.6.1 OpenXR export implementation](https://github.com/godotengine/godot/blob/4.6.1-stable/modules/openxr/editor/openxr_editor_plugin.cpp)

## Session and input behavior

- Browser VR and AR capabilities are checked independently. Session requests run directly from a button press without awaiting a support query first.
- Optional `bounded-floor` / `local-floor` features allow a `local` reference-space fallback. A calibrated eye-height offset is applied once for VR local-space sessions and removed on exit.
- Tracked right aim is preferred, then left aim, then a head-gaze ray. WebXR `select` routes a transient source's own aim pose, supporting controller, pinch or screen input where the runtime exposes it.
- VR navigation is available in a compact Greek world-space menu: Συλλογή, Αμπελώνας, Οινοποιείο and Έξοδος XR. It stays still while selected, including gaze-based selection, and remains in front of the inspected fruit. In AR the menu offers Συλλογή, Μετακίνηση and Έξοδος XR; opaque vineyard/cellar environments cannot replace passthrough.
- With both controllers tracked, hold the left trigger or push the left stick forward to preview the ballistic teleport arc; release to move. With one tracked controller, its trigger remains available for selection, while forward stick or secondary button aims teleport. Changing or losing tracking cancels a pending arc. Floor group, bounds, obstacles, surface normal and destination body clearance must all pass. Right-stick horizontal input turns by 30 degrees around the real head position. Artificial locomotion is disabled in AR.
- Museum physical grasping prefers the right controller's grip pose and falls back to the left grip when only that hand tracks. The corresponding anatomical glove holds and releases the grape. Losing tracking or changing the preferred hand releases the grasp; an already-held squeeze cannot transfer the fruit to the other hand. A fresh squeeze starts the next grasp. A dead zone prevents squeeze chatter. This supports one held grape at a time, not simultaneous two-hand grabs.
- Input starts only when the runtime reports focus. Focus loss or an open app modal disables selection, grabbing and teleport. Browser exit, session loss and failed or timed-out requests restore viewport transparency and physics timing. A timed-out permission prompt must settle before retry; a late grant is closed instead of overlapping a new request. A native OpenXR interface remains initialized so its startup graphics integration is preserved.

AR currently displays the collection in the runtime's reference space. It does **not** implement real-world surface hit testing, persistent spatial anchors, room meshing, camera-marker recognition or infrared scanning. The on-screen collection codes select authored content; they do not imply these hardware features. [Godot WebXR interface](https://docs.godotengine.org/en/stable/classes/class_webxrinterface.html), [Godot AR / passthrough](https://docs.godotengine.org/en/stable/tutorials/xr/ar_passthrough.html)

## Automated checks

From the project folder, run:

```powershell
& 'C:/Users/Marios/Godot/Godot_v4.6.1-stable_win64_console.exe' --headless --xr-mode off --path . --script scripts/vr/tests/validate_xr.gd
& 'C:/Users/Marios/Godot/Godot_v4.6.1-stable_win64_console.exe' --headless --xr-mode off --path . scenes/dev/XRIntegrationQA.tscn
& 'C:/Users/Marios/Godot/Godot_v4.6.1-stable_win64_console.exe' --headless --xr-mode off --path . scenes/dev/XRGraspQA.tscn
```

The harness checks unsupported-mode fallback, independent browser capability results, AR blend selection, idempotent exit/timeout callbacks, transparency/physics restoration, gaze fallback, real-head snap turning, local eye-height resets, action-map profiles, and the actual physics path of a simulated tracked teleport arc with and without a wall. It requires no headset and does not replace headset testing.

The full-scene integration harness passed 52 checks, including the actual ray-to-hover-to-controller-to-Interactable path for all three environments during grape inspection, real left/right controller signal routing, safe exit while the menu is selected, focus/modal gating, independent VR/AR menu availability, AR environment restoration, hidden-room collider cleanup, exclusion of legacy vial overlays and scene changes retaining the calibrated reference-space height. Its session callbacks are explicitly simulated. A native desktop capture run passed the earlier 47-check revision with no rendering-resource leak warning; its images verify menu readability but do not validate stereo rendering or passthrough. The unit harness also passes actual initial runtime-focus handling, permission timeout/retry serialization, tracked-controller fallback and cancellation of pending teleport on tracking loss.

For each target headset/browser, additionally verify stereo scale, stable frame timing, left/right bindings, grabbing/release, controller tracking loss, gaze or pinch selection, floor height, teleport obstruction, system-menu focus loss, return to desktop, repeated entry and exit, and real AR background visibility. Export output belongs in ignored local build folders; every platform preset includes runtime JSON data and imported resources and excludes development harnesses and generated builds.

The dedicated XR grasp harness passed 20 checks using registered controller trackers and actual physics frames: separated aim/grip poses, left-only grab/drag/release, matching glove/collision behavior, squeeze hysteresis, right preference, release on tracking handover, fresh-squeeze rearming and complete tracking loss. It uses the real collection scene and does not replace physical-controller acceptance testing.
