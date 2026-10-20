<div align="center">

# Godot Animated Image

为 Godot 4 提供统一的 GIF、APNG 与 Animated WebP 支持。

[English](README.md) | 简体中文

<p>
  <img src="https://img.shields.io/badge/Godot-4.x-478CBF" alt="Godot">
  <img src="https://img.shields.io/badge/平台-Windows-0078D6" alt="Platform">
  <img src="https://img.shields.io/badge/GDExtension-C%2B%2B20-blue" alt="GDExtension">
  <img src="https://img.shields.io/badge/GIF-支持-brightgreen" alt="GIF">
  <img src="https://img.shields.io/badge/APNG-支持-brightgreen" alt="APNG">
  <img src="https://img.shields.io/badge/Animated%20WebP-支持-brightgreen" alt="Animated WebP">
  <img src="https://img.shields.io/badge/许可证-MIT-green" alt="License">
</p>

</div>

---

> [!IMPORTANT]
> **当前官方仅支持 Windows 平台。**
>
> Linux、macOS、Android、iOS、Web 等其他平台在当前版本中均不属于官方支持范围，也不保证能够正常工作。

> [!NOTE]
> 本项目基于 / fork 自 [BOTLANNER/godot-gif](https://github.com/BOTLANNER/godot-gif)。
>
> 原项目使用 MIT License。

> [!WARNING]
> 本插件不会内置限制图片尺寸、动画帧数或内存占用。若程序需要加载不可信或用户提供的图片数据，请自行进行输入大小和资源占用校验。

## 项目简介

**Godot Animated Image** 是一个面向 Godot 4 的 GDExtension 插件，为多种动态图片格式提供统一的加载与播放 API。

当前支持：

- GIF
- APNG
- Animated WebP

插件既可以直接从文件加载动态图片，也可以直接从内存字节数据加载，并通过适合 Godot 使用的资源与播放接口进行处理。

格式检测基于文件签名 / Magic Bytes，而不是单纯依赖文件扩展名。

因此，即使文件扩展名缺失或错误，插件仍然可以根据真实二进制内容识别格式。

例如，一个扩展名为 `.png`、但内部实际存储的是 Animated WebP 数据的文件，在从 CHARX 压缩包或内存缓冲区读取时仍然可以被正确识别。

## 平台支持

| 平台 | 当前状态 |
| --- | --- |
| Windows | ✅ 官方支持 |
| Linux | ❌ 当前不支持 |
| macOS | ❌ 当前不支持 |
| Android | ❌ 当前不支持 |
| iOS | ❌ 当前不支持 |
| Web | ❌ 当前不支持 |

当前版本主要在 **Windows** 平台开发和测试。

未来可能会增加其他平台支持。

## 功能特性

- 统一的 `AnimatedImageManager` API
- 支持从文件或内存字节加载动态图片
- 基于 Magic Bytes 的格式检测
- GIF 解码
- APNG 解码
- Animated WebP 解码
- Animated WebP 使用内置的 `libwebp`
- 支持 APNG dispose / blend 帧合成
- 编辑器导入器：**Animated Image**
- 可导入为 `AnimatedImageTexture`
- 提供 `AnimatedImagePlayer` 播放节点
- 单一 `animated_image` 资源槽
- 可在不完整解码动画帧的情况下检测格式
- 兼容原 Godot-GIF API
- 保留 `GIFTexture`、`GIFPlayer`、`GIFReader`、`GIFWriter` 等 API

## 支持的图片格式

| 格式 | 解码 | 文件加载 | 内存加载 | 动画 |
| --- | --- | --- | --- | --- |
| GIF | ✅ | ✅ | ✅ | ✅ |
| PNG | 格式检测 | ✅ | ✅ | ❌ |
| APNG | ✅ | ✅ | ✅ | ✅ |
| WebP | 格式检测 | ✅ | ✅ | ❌ |
| Animated WebP | ✅ | ✅ | ✅ | ✅ |

## 项目结构

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

## 环境要求

### 普通插件用户

当前版本需要：

- Windows
- Godot 4
- `addons/godot_animated_image/` 插件目录

如果直接使用项目提供的 Windows 预编译版本，普通用户不需要额外安装 C++、SCons 或 libwebp。

### 从源码编译

需要：

- Python 3.8+
- SCons 4.0+
- 支持 C++20 的编译器
- `godot-cpp` Git 子模块

Windows 平台推荐使用 MSVC。

## 安装

将：

```text
addons/godot_animated_image/
```

复制到你的 Godot 项目：

```text
res://addons/godot_animated_image/
```

项目结构应类似：

```text
your_project/
├── addons/
│   └── godot_animated_image/
└── project.godot
```

然后打开 Godot，进入：

```text
项目
→ 项目设置
→ 插件
```

启用：

```text
Godot Animated Image
```

> [!IMPORTANT]
> 当前发布版本仅面向 Windows 项目。

## 使用方法

### 1. 从文件加载动态图片

```gdscript
var player := AnimatedImagePlayer.new()
add_child(player)

player.load_from_file("res://character.webp")
```

同一套 API 可以用于 GIF、APNG 和 Animated WebP。

### 2. 使用编辑器导入的动态图片

在 Godot 编辑器中将图片导入类型设置为：

```text
Animated Image
```

然后将资源赋值给 `animated_image`：

```gdscript
player.animated_image = load("res://character.webp")
player.play()
```

也可以直接在 Inspector 中拖入导入后的资源。

### 3. 从内存加载动态图片

```gdscript
player.load_from_buffer(bytes)
```

适用于：

- 压缩包资源
- 网络响应
- 加密资源包
- CHARX 文件
- 自定义资源容器
- 内存资源系统

### 4. 检测图片格式

```gdscript
var fmt := AnimatedImageManager.detect_format_from_buffer(bytes)
print(AnimatedImageManager.format_name(fmt))
```

格式检测使用真实二进制文件签名，而不是仅依赖文件扩展名。

## 旧版 GIF API

原 Godot-GIF 风格 API 仍然保留。

```gdscript
var gif := GIFTexture.load_from_file("res://animation.gif")
$TextureRect.texture = gif
```

兼容类包括：

```text
GIFTexture
GIFPlayer
GIFReader
GIFWriter
```

这样可以让原本基于 Godot-GIF API 的项目更容易迁移到本插件。

## 从源码编译

克隆仓库：

```bash
git clone --recursive https://github.com/513195902/godot_animated_image.git
```

如果之前克隆时没有初始化子模块：

```bash
git submodule update --init --recursive
```

Windows Debug 构建：

```bash
scons platform=windows target=template_debug
```

Windows Release 构建：

```bash
scons platform=windows target=template_release
```

目前本项目仅正式支持 Windows 构建。

## 测试

无界面测试脚本位于：

```text
demo/tests/
```

例如：

```bash
godot --headless --path demo --script res://tests/run_format_detect.gd
godot --headless --path demo --script res://tests/run_webp_decode.gd
godot --headless --path demo --script res://tests/run_apng_decode.gd
godot --headless --path demo --script res://tests/run_phase5_limits.gd
```

测试内容包括：

- 格式检测
- GIF 解码
- APNG 解码
- Animated WebP 解码
- Manager API
- 非法输入处理
- 资源限制相关测试
- 编辑器集成

## 格式检测

Godot Animated Image 使用二进制文件签名识别图片格式。

例如：

```text
character.png
```

虽然扩展名是 PNG，但实际内容如果是：

```text
Animated WebP
```

插件仍然可以正确识别。

这对于不能完全信任资源文件扩展名的应用场景尤其有用。

## 第三方库

本项目包含或依赖以下开源组件：

- `godot-cpp`
- `giflib`
- `libwebp`

第三方许可证信息请查看：

```text
THIRD_PARTY_LICENSES.md
```

## 注意事项

动态图片解码后的内存占用可能远大于原始压缩文件大小，因为动画帧通常需要以未压缩图片或纹理数据的形式存储。

如果需要处理不可信或用户提供的文件，建议自行检查：

- 图片宽高
- 动画帧数量
- 解码后内存占用
- 原始文件大小
- 动画持续时间

本插件刻意不设置固定的全局限制，以便不同项目根据自己的使用场景决定合理的限制策略。

## 兼容性

- 引擎：Godot 4
- 扩展方式：GDExtension
- 当前官方支持平台：**Windows**
- 其他平台：当前不支持 / 未验证

## 免责声明

本项目作为开源软件提供，可用于 Godot 项目开发、学习和研究。

当程序需要处理不可信的动态图片文件时，开发者应根据自身项目需要设置适当的输入校验和资源限制。

本项目不保证所有损坏、异常或不受支持的图片文件都能够成功解码。

## 许可证

本项目使用 MIT License。

详见：

```text
LICENSE
```

本项目基于 / fork 自：

[**BOTLANNER/godot-gif**](https://github.com/BOTLANNER/godot-gif)

原项目的 MIT License 与原作者署名信息会继续保留。

第三方组件使用各自对应的许可证，详见：

```text
THIRD_PARTY_LICENSES.md
```

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=513195902/godot_animated_image&type=Date)](https://www.star-history.com/#513195902/godot_animated_image&Date)
