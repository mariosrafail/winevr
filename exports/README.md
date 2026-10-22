# Local export targets

Use Godot **4.6.1 stable** with its matching export templates. Generated packages stay local and are not source deliverables.

| Preset | Output | Purpose |
| --- | --- | --- |
| Windows Desktop | `build/WineVR.exe` + `WineVR.pck` | Windows keyboard/mouse and supported PC OpenXR runtimes |
| Linux | `build_linux/WineVR.x86_64` + `WineVR.pck` | Linux desktop / supported OpenXR runtime; requires testing on Linux |
| macOS Desktop | `exports/local/macos/WineVR.zip` | Unsigned universal desktop application; requires testing on macOS |
| Web | `exports/local/web/WineVR.html` and adjacent files | WebGL 2 desktop/touch; conditional WebXR VR/AR |
| Android Touch | `exports/local/android/WineVR-Touch.apk` | Debug-signed phone/tablet build, Compatibility renderer, OpenXR disabled |
| Android OpenXR | `exports/local/android/WineVR.apk` | Configuration only: export currently blocked by missing Gradle project template/toolchain prerequisites |

## Rebuild desktop and Web

```powershell
./tools/export_local.ps1 -Godot 'C:/path/to/Godot_v4.6.1-stable_win64_console.exe'
```

The helper imports assets, exports each preset sequentially and writes logs plus primary-file SHA-256 hashes to `work/export-logs`. `-Target Web` or `-Target Desktop` limits the work. It checks the engine version and fails when an export fails. It does not download templates, install tools, change user editor settings, publish or sign a release.

The Web preset includes both desktop and mobile compressed textures. `textures/vram_compression/import_etc2_astc` must remain enabled in the project so the mobile export validates. Web uses Compatibility and no worker threads. Serve the repository on localhost for review; production WebXR requires HTTPS, supported browser/device and `xr-spatial-tracking` permission. All files from the Web export must be deployed together. The source `index.html` is a separate launcher for that export.

Windows and Linux applications need their adjacent PCK. Do not distribute the executable alone. The macOS ZIP contains the application bundle; it is not notarized. Android Touch uses a debug signing identity and is intended for local testing, not store publication.

## Android distinction

The touch and headset presets are intentionally separate. The prebuilt Android template can produce a touch APK but contains no OpenXR loader. Android OpenXR requires the Godot Android build template and matching Gradle/SDK prerequisites; see [XR compatibility](../docs/xr_compatibility.md). Export success is not evidence of testing on a physical phone or headset.

## Export contents

All presets include runtime JSON and imported resources. They exclude development scenes/scripts, QA captures, build folders, Blender source assets and website-only promotional images. Keep source data and attribution files with the project. Locally generated build files and logs belong in ignored folders.
