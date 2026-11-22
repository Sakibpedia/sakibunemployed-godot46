# Building the .exe, the web version (.html) and the Android .apk

*S M Nazmuz Sakib is unemployed* — developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib.

The project ships with everything Godot needs to export, but the builds themselves have to be made by
Godot 4.6 on a computer that has the export templates. There are three ways to do it.

| Target | Preset name | Renderer | Output |
|---|---|---|---|
| Windows | `Windows Desktop` | Forward+ (full quality tiers) | `build/windows/SakibUnemployed.exe` (one file, data embedded) |
| Browser | `Web` | Compatibility (WebGL 2) | `build/web/index.html` + `.js`, `.wasm`, `.pck` |
| Android | `Android` | Mobile | `build/android/SakibUnemployed.apk` (arm64) |

The renderer is switched automatically by `project.godot`
(`rendering_method.mobile="mobile"`, `rendering_method.web="gl_compatibility"`), and
`RenderQuality.gd` drops to the Low tier on those renderers (no SDFGI, SSIL, volumetric fog or FSR).
On phones and phone browsers `Game.touch_mode` turns on and `TouchControls.gd` shows a movement stick,
a look pad and Bengali action buttons (মারো, লাফ, দৌড়, কথা, গাড়ি, তাক, রিলোড, টর্চ, পট্টি, মানচিত্র, মিশন, বিরতি).
The layout is shown in `docs/img/touch_layout.jpg`.

## 1. GitHub Actions (nothing to install)

1. Put the project folder in a GitHub repository (private is fine) and push it.
2. Open **Actions → Export game (exe, web, apk) → Run workflow**.
3. When it finishes, download the three artifacts from the run page.

The workflow (`.github/workflows/export.yml`) downloads Godot 4.6-stable and its templates, makes a debug
signing key for the APK and runs `export_all.sh`. Pushing a tag such as `v0.3.0` runs it too.

## 2. One command on your own computer

1. Install **Godot 4.6** (standard, not .NET) and, in the editor, **Editor → Manage Export Templates → Download**.
2. For Android only: install **JDK 17** and the **Android SDK** (Android Studio installs both), then set
   **Editor → Editor Settings → Export → Android → Android SDK Path / Java SDK Path**.
3. Run:
   - Windows: `set GODOT=C:\path\to\Godot_v4.6-stable_win64_console.exe` then `export_all.bat`
   - Linux/macOS: `GODOT=/path/to/godot ./export_all.sh`
   - Just some targets: `export_all.bat windows web` or `./export_all.sh android`

## 3. From the editor

Open the project, **Project → Export…**, pick a preset, **Export Project**.

## Signing the APK

Without settings, the scripts export a **debug-signed** APK (`SakibUnemployed-debug.apk`), which installs
on your own phone after allowing "install unknown apps". For a Play Store or public release, make a key once:

```
keytool -genkeypair -v -keystore sakib-release.keystore -alias sakib -keyalg RSA -keysize 2048 -validity 10000
```

then set these before running the script (never commit the keystore or the password):

```
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/sakib-release.keystore
GODOT_ANDROID_KEYSTORE_RELEASE_USER=sakib
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=********
```

## Running the web build

Browsers will not run Godot from `file://`. Serve the folder:

```
python -m http.server 8060 --directory build/web
```

and open `http://localhost:8060`. The preset uses the single-threaded web template
(`variant/thread_support=false`), so any static host (GitHub Pages, Netlify, itch.io) works without
special COOP/COEP headers. The first load downloads the full texture set, so expect a large `.pck`.

## What is and is not in the exports

`export_filter="all_resources"` plus `include_filter="*.json, *.txt"`, so the city layout, story,
missions, question banks, faces table and copyright notice are packed. `tools/`, `docs/`, `legacy/`,
`build/`, Python scripts and Markdown files are excluded.

## Known limits

- These builds were not produced or tested in this workspace (no Godot binary here). Expect to fix
  small issues on the first export, especially on the web and Android renderers.
- Bengali speech (text-to-speech) depends on a Bengali voice being installed on the device or in the
  browser. Without one, the Bengali subtitles still show and the voice speaks the English version of
  the line (or stays silent if the device has no voices at all).
- The web and phone builds look plainer than the Windows build (Low tier, no global illumination).
