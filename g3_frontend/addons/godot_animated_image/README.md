<div align="center">

# Godot Animated Image

Unified GIF, APNG, and Animated WebP support for Godot 4.

English | [简体中文](README_zh.md)

<p>
  <img src="https://img.shields.io/badge/Godot-4.x-478CBF" alt="Godot">
  <img src="https://img.shields.io/badge/platform-Windows-0078D6" alt="Platform">
  <img src="https://img.shields.io/badge/GDExtension-C%2B%2B20-blue" alt="GDExtension">
  <img src="https://img.shields.io/badge/GIF-supported-brightgreen" alt="GIF">
  <img src="https://img.shields.io/badge/APNG-supported-brightgreen" alt="APNG">
  <img src="https://img.shields.io/badge/Animated%20WebP-supported-brightgreen" alt="Animated WebP">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

</div>

---

> [!IMPORTANT]
> **Current official platform support: Windows only.**
>
> Other platforms are not officially supported or guaranteed to work in the current release.

> [!NOTE]
> This project is based on / forked from [BOTLANNER/godot-gif](https://github.com/BOTLANNER/godot-gif).
>
> The original project is licensed under the MIT License.

> [!WARNING]
> This plugin does not impose built-in image size, frame count, or memory limits. Applications that load untrusted image data should validate input size and resource usage themselves.

## Introduction

**Godot Animated Image** is a GDExtension plugin for Godot 4 that provides a unified API for loading and playing animated image formats.

It currently supports:

- GIF
- APNG
- Animated WebP

The plugin can load animated images from files or directly from memory buffers and expose them through Godot-friendly animation resources and playback APIs.

Format detection is based on file signatures / magic bytes instead of file extensions. This means image data can still be detected correctly even when the extension is missing or misleading.

For example, a file named `.png` that actually contains Animated WebP data can still be recognized correctly when loaded from a CHARX archive or memory buffer.

## Platform Support

| Platform | Status |
| --- | --- |
| Windows | ✅ Officially supported |
| Linux | ❌ Not currently supported |
| macOS | ❌ Not currently supported |
| Android | ❌ Not currently supported |
| iOS | ❌ Not currently supported |
| Web | ❌ Not currently supported |

The current release is developed and tested for **Windows**.

Support for additional platforms may be added in the future.

## Features

- Unified `AnimatedImageManager` API
- Load animated images from files or memory buffers
- Magic-byte format detection
- GIF decoding
- APNG decoding
- Animated WebP decoding
- Animated WebP powered by vendored `libwebp`
- APNG dispose / blend frame composition
- Editor importer: **Animated Image**
- Import animated images as `AnimatedImageTexture`
- `AnimatedImagePlayer` node for playback
- Single `animated_image` resource slot
- Detect formats without fully decoding frames
- Backward-compatible Godot-GIF APIs
- Existing `GIFTexture`, `GIFPlayer`, `GIFReader`, and `GIFWriter` APIs remain available

## Supported Image Formats

| Format | Decode | File Loading | Buffer Loading | Animation |
| --- | --- | --- | --- | --- |
| GIF | ✅ | ✅ | ✅ | ✅ |
| PNG | Detection | ✅ | ✅ | ❌ |
| APNG | ✅ | ✅ | ✅ | ✅ |
| WebP | Detection | ✅ | ✅ | ❌ |
| Animated WebP | ✅ | ✅ | ✅ | ✅ |

## Project Structure

```text
.
├── addons/
│   └── godot_animated_image/
│       ├── bin/
│       ├── godot_animated_image.gd
│       ├── plugin.cfg
│       └── README.md
├── demo/
│   ├── addons/
│   ├── tests/
│   └── project.godot
├── doc_classes/
├── godot-cpp/
├── scripts/
├── src/
│   ├── animated_image/
│   ├── apng/
│   ├── core/
│   ├── editor/
│   ├── node/
│   ├── png/
│   ├── thirdparty/
│   └── webp/
├── LICENSE
├── README.md
├── README_zh.md
├── THIRD_PARTY_LICENSES.md
└── SConstruct
```

## Requirements

### For Plugin Users

For the current release:

- Windows
- Godot 4
- The `addons/godot_animated_image/` directory

Normal plugin users do not need to install C++, SCons, or libwebp separately when using the included prebuilt Windows binary.

### For Building from Source

- Python 3.8+
- SCons 4.0+
- C++20-compatible compiler
- `godot-cpp` submodule

On Windows, MSVC is recommended.

## Installation

Copy:

```text
addons/godot_animated_image/
```

into your Godot project's:

```text
res://addons/godot_animated_image/
```

Your project should look similar to:

```text
your_project/
├── addons/
│   └── godot_animated_image/
└── project.godot
```

Then open Godot and go to:

```text
Project
→ Project Settings
→ Plugins
```

Enable:

```text
Godot Animated Image
```

> [!IMPORTANT]
> The current release is intended for Windows projects only.

## Usage

### 1. Load an Animated Image from a File

```gdscript
var player := AnimatedImagePlayer.new()
add_child(player)

player.load_from_file("res://character.webp")
```

The same API can be used for GIF, APNG, and Animated WebP.

### 2. Use an Imported Animated Image

Import the image as **Animated Image** in the Godot editor, then assign it to the `animated_image` property.

```gdscript
player.animated_image = load("res://character.webp")
player.play()
```

You can also assign the imported resource directly from the Inspector.

### 3. Load an Animated Image from Memory

```gdscript
player.load_from_buffer(bytes)
```

This is useful when loading assets from:

- archives
- network responses
- encrypted packages
- CHARX files
- custom resource containers
- in-memory asset systems

### 4. Detect the Image Format

```gdscript
var fmt := AnimatedImageManager.detect_format_from_buffer(bytes)
print(AnimatedImageManager.format_name(fmt))
```

Detection uses the actual binary signature instead of relying only on the filename extension.

## Legacy GIF API

Existing Godot-GIF style APIs remain supported.

```gdscript
var gif := GIFTexture.load_from_file("res://animation.gif")
$TextureRect.texture = gif
```

Legacy classes include:

```text
GIFTexture
GIFPlayer
GIFReader
GIFWriter
```

This makes it easier for projects based on the original Godot-GIF API to migrate.

## Building from Source

Clone the repository:

```bash
git clone --recursive https://github.com/513195902/godot_animated_image.git
```

If the repository was cloned without submodules:

```bash
git submodule update --init --recursive
```

Build on Windows:

```bash
scons platform=windows target=template_debug
```

Release build:

```bash
scons platform=windows target=template_release
```

At present, only the Windows build is officially supported by this project.

## Tests

Headless test scripts are available under:

```text
demo/tests/
```

Examples:

```bash
godot --headless --path demo --script res://tests/run_format_detect.gd
godot --headless --path demo --script res://tests/run_webp_decode.gd
godot --headless --path demo --script res://tests/run_apng_decode.gd
godot --headless --path demo --script res://tests/run_phase5_limits.gd
```

The tests cover areas such as:

- format detection
- GIF decoding
- APNG decoding
- Animated WebP decoding
- manager APIs
- invalid input handling
- resource limits
- editor integration

## Format Detection

Godot Animated Image detects formats using their binary signatures.

This allows a file such as:

```text
character.png
```

whose actual data is:

```text
Animated WebP
```

to still be recognized correctly.

This is especially useful for applications where asset extensions cannot be trusted.

## Third-Party Libraries

This project includes or depends on third-party open-source components, including:

- `godot-cpp`
- `giflib`
- `libwebp`

See:

```text
THIRD_PARTY_LICENSES.md
```

for additional license information.

## Notes

Animated images can consume significantly more memory than their compressed file size because decoded frames may need to be stored as raw image or texture data.

Applications processing untrusted or user-provided files should consider validating:

- image dimensions
- frame count
- decoded memory usage
- source file size
- animation duration

The plugin intentionally does not enforce fixed global limits so applications can choose limits appropriate for their own use case.

## Compatibility

- Engine: Godot 4
- Extension system: GDExtension
- Current officially supported platform: **Windows**
- Other platforms: currently unsupported / unverified

## Disclaimer

This project is provided as open-source software for development, learning, research, and use in Godot projects.

When processing untrusted animated image files, developers are responsible for applying appropriate input validation and resource limits for their application.

No guarantee is made that every malformed or unsupported image file can be decoded successfully.

## License

This project is distributed under the MIT License.

See:

```text
LICENSE
```

This project is based on / forked from:

[**BOTLANNER/godot-gif**](https://github.com/BOTLANNER/godot-gif)

The original project's MIT license and attribution are preserved.

Third-party components have their own applicable licenses. See:

```text
THIRD_PARTY_LICENSES.md
```

for details.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=513195902/godot_animated_image&type=Date)](https://www.star-history.com/#513195902/godot_animated_image&Date)
