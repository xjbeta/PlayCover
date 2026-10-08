<p align="center">
  <b>English</b> · <a href="README.zh-Hans.md">简体中文</a>
</p>

<div align="center">
  <img src="images/endfield-logo.png" alt="Logo" width="80" height="80">

  <h3 align="center">PlayCover · Endfield Edition</h3>

  <p align="center">
    A fork of <a href="https://github.com/viatearz/PlayCover">viatearz/PlayCover</a> with extra patches for <em>Arknights: Endfield</em>
    <br />
    <br />
    <a href="https://github.com/xjbeta/PlayCover/actions/workflows/unsigned_release.yml">Download build (GitHub Actions)</a>
    ·
    <a href="https://playcover.github.io/PlayBook">Upstream docs</a>
    ·
    <a href="https://playcover.io/">Website</a>
  </p>
</div>

> [!WARNING]
> Everything in this fork modifies the game and may be detected by anti-cheat — **your account could be banned. Use at your own risk.**

---

## What this is

This repository is a **fork of [viatearz/PlayCover](https://github.com/viatearz/PlayCover)**.

- `viatearz/PlayCover` is itself a modified build of [PlayCover](https://github.com/PlayCover/PlayCover) with experimental bugfixes and features.
- On top of that, this fork **adds a set of extra patches and fixes specifically for _Arknights: Endfield_** (see "Endfield-specific features" below).

> Everything other than the Endfield changes comes from the upstream projects above. This build is **experimental** and may be unstable; if you only need the general functionality, prefer the official or viatearz builds.

## Endfield-specific features

The app settings get a dedicated **"Endfield" tab** containing the switches below. Every switch is **gated to Endfield only**
(bundle id `com.hypergryph.endfield` / `com.gryphline.endfield.ios`) and has no effect on other apps.

| Feature | Description |
|---|---|
| **Resolution Fix** | No longer pinned to the game's default 1080p; follows the "Resolution" and "Resolution Scale" options in the graphics settings |
| **Double the frame-rate tiers** | 30/45/60 → 60/90/120, and lifts the engine's internal frame-rate cap |
| **Restore controller rumble** | Fixes broken rumble (never rumbles / normal attacks don't rumble) and adds multi-motor support (left/right grips + left/right triggers, graded output) |
| **Volume boost** | Bypasses the in-game 100% volume cap (adds gain after Wwise renders), 100–150%, 100% = off |
| **Clear Shader Cache** | Removes the warm-up marker so the game re-runs "Compiling Shader Cache" on next launch. Use after a macOS update when stutter appears |

### Fixes that require the keyboard/mouse plugin

The following two depend on the third-party plugin **`libUnityDesktopMode`**; the switches stay disabled until it is installed.
Download it from the [Bilibili video](https://www.bilibili.com/video/BV14xHz65Eiv), then install it inside PlayCover:
right-click the app → **Settings → Misc → Custom Plugins → Add…**, pick the `.dylib` and confirm **Add Anyway**.
PlayCover copies it into the app's `Frameworks/UserPlugins/`.

| Feature | Description |
|---|---|
| **Gamepad Map Key Fix** | Fixes the gamepad buttons misbehaving after the plugin is installed |
| **Mouse look scale** | Fixes the camera turning too slowly with the mouse in keyboard/mouse mode (extra multiplier slider 0–3, 1.0 is the corrected value) |

> **Keyboard/mouse mode switching** is handled by the plugin itself. This repository does not maintain that plugin; it only relies on its presence.

## How to Use

1. Manually trigger `Build unsigned release` in [GitHub Actions](https://github.com/xjbeta/PlayCover/actions/workflows/unsigned_release.yml)
   and download the `PlayCover_custom_<run>.dmg` artifact.
2. Install the app.
3. Remove the quarantine attribute:
   ```bash
   xattr -dr com.apple.quarantine /Applications/PlayCover.app
   ```

### Migrating from the official build

If you already installed an app using the official (or another) build, it is recommended to:

1. Right-click the app icon → `Settings` → click `Reset Settings` at the bottom to restore the recommended configuration.
2. Reinstall the app, since some tweaks are only applied during installation.

## Building from source

This fork depends on the `dev` branch of [xjbeta/PlayTools](https://github.com/xjbeta/PlayTools) (where the Endfield modules live).
`Cartfile` already points there:

```
github "xjbeta/PlayTools" "dev"
```

The build steps are the same as upstream (Carthage + Xcode). Note that PlayCover's build phase **re-runs carthage**,
so whatever `Cartfile` points to is what gets compiled.

## License

Distributed under the **GPLv3** License. See `LICENSE` for more information.

## Acknowledgments

- [PlayCover](https://github.com/PlayCover/PlayCover) — the original project, thanks to @iVoider;
- [viatearz/PlayCover](https://github.com/viatearz/PlayCover) — the direct upstream of this fork;
- The author of the `libUnityDesktopMode` plugin — provides keyboard/mouse mode switching (an external dependency not maintained here);
- [DeepSeek](https://www.deepseek.com/) — assisted with the development of the Endfield patches.

## Libraries Used

- [inject](https://github.com/paradiseduo/inject)
- [PTFakeTouch](https://github.com/Ret70/PTFakeTouch)
- [DownloadManager](https://github.com/shapedbyiris/download-manager)
- [DataCache](https://github.com/huynguyencong/DataCache)
- [SwiftUI CachedAsyncImage](https://github.com/bullinnyc/CachedAsyncImage)
