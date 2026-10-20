# Godot Animated Image — StoryTavern 使用指南（性能版）

面向 Godot 4：**GIF / APNG / Animated WebP** 统一 API。  
默认路径为 **STREAM（懒解码）**；转码 / 随机访问需显式 **eager**。

插件目录：

- 开发树：`godot-animated-image/addons/godot_animated_image/`
- 发布副本：`dist/addons/godot_animated_image/`

---

## 1. 安装

1. 复制整个 `addons/godot_animated_image/` 到项目 `addons/`  
2. **项目 → 项目设置 → 插件** → 启用 **Godot Animated Image**  
3. 终端用户无需自行编译 C++

---

## 2. 性能模型（必读）

| 模式 | `decode_mode` | 行为 | 适用 |
|---|---|---|---|
| **STREAM（默认）** | `"stream"` / `"lazy"` / 省略 | 增量解码；只保留约 3 帧 GPU 纹理（ring-buffer）；播到第 N 帧不会全量展开 | 聊天背景、消息动图、`AnimatedImagePlayer` |
| **POSTER** | `"poster_only"` 或 `load_poster_*` | 只解第 0 帧 | 列表缩略图、头像 |
| **EAGER** | `"eager"` / `"full"` / `"random_access"` 或 `ensure_eager()` | 全部帧 `ImageTexture` | 转码、导出、编辑器导入、需要任意 `get_frame_texture(i)` 且常驻全帧 |

**不要指望一个默认 load 同时满足：流畅播放 + 任意随机访问 + 转码。**  
播放用 STREAM；后两者显式 eager。

### probe 是轻量的

`probe_file` / `probe_bytes` **不解码像素**：

- GIF：header + record 扫描（**不** `DGifSlurp`）  
- APNG / WebP：chunk 扫描  

适合 Library 批量判断 `animated` / 尺寸 / 帧数。

### 会让你怎么修都卡的用法（业务层）

1. Library 对大量文件 **同步 probe 后再 `load_from_file` 全量进内存**  
2. 超大画布 + 多个动画同时全屏每帧 redraw  
3. 默认 eager / `SpriteFrames` 一次备齐所有帧  

这些不是「统一 `animated_image` 槽」的锅；槽位可以很快，成本在解码策略与调用方。

---

## 3. 推荐主路径

```text
列表 / 扫描     → AnimatedImageLoader.probe_*          （轻）
缩略图         → load_poster_from_file / from_bytes    （仅第 0 帧）
播放           → load_from_*（默认 STREAM）
               → AnimatedImagePlayer.animated_image
转码 / 导出    → load(..., {decode_mode:"eager"})
               或 tex.ensure_eager() 再 Encoder / Transcoder
```

```gdscript
# 播放（默认 stream）
var tex := AnimatedImageLoader.load_from_file(path)
player.animated_image = tex
player.play()

# 列表
var info := AnimatedImageLoader.probe_file(path)
if bool(info.get("animated", false)):
    $Thumb.texture = AnimatedImageLoader.load_poster_from_file(path)

# 转码（必须 eager）
var opts := {"decode_mode": "eager"}
var full := AnimatedImageLoader.load_from_bytes(bytes, "", opts)
# 或:
# var stream_tex := AnimatedImageLoader.load_from_file(path)
# stream_tex.ensure_eager()
var out := AnimatedImageTranscoder.convert(bytes, "apng", {})
```

异步：

```gdscript
AnimatedImageLoader.load_from_file_async(path, func(tex):
    if tex == null:
        return
    player.animated_image = tex
    player.play()
)
# 切场景时取消在途任务（取消的不回调）
AnimatedImageLoader.cancel_async_loads()
```

别名 **`AnimatedImage`** 与 `AnimatedImageLoader` 方法一致。

---

## 4. 节点与资源

| 需求 | API |
|---|---|
| UI 播放 | **`AnimatedImagePlayer`**（`animated_image` 槽：GIF/APNG/WebP 同一入口） |
| 只显示封面 | `load_poster_*` 或 `get_poster_texture()` |
| 加载 / 探测 | **`AnimatedImageLoader`** / **`AnimatedImage`** |
| 导出 Character Card APNG | **`AnimatedImageEncoder` + `PngMetadata`** |
| 格式互转 | **`AnimatedImageTranscoder.convert`**（内部强制 eager） |
| 旧兼容 | **`GIFTexture` / `GIFPlayer` / `GIFWriter`** 仍可用 |

```gdscript
@onready var player: AnimatedImagePlayer = $AnimatedImagePlayer

func _ready() -> void:
    player.load_from_file("res://avatars/hero.webp")  # STREAM
    player.frame_changed.connect(func(i): pass)
```

同一份 STREAM 纹理：

- 可给一个 `AnimatedImagePlayer` 播放  
- 可用 `get_poster_texture()` 做静态展示  

**不要**为每个控件各自 `load_from_file` 一遍。  
可选缓存：`AnimatedImageCache.get_or_load_file(path, opts)`（注意共享实例的 `frame` 会互相影响，列表更推荐 poster）。

---

## 5. `AnimatedImageTexture` API 要点

| 方法 | STREAM 行为 |
|---|---|
| `get_frame_texture(i)` / `set_frame(i)` | **增量**解码到 i（必要时从 0 重放合成）；只保留 ring 内少量纹理；**不会**因播第 2 帧而全量展开 |
| `get_total_duration()` / `get_frame_count()` | 用 probe/metadata，不触发全量 RGBA |
| `ensure_eager()` | 显式物化全部帧；之后 `is_eager()==true` |
| `get_decode_mode()` | `"stream"` / `"eager"` / `"poster_only"` |

诊断：`AnimatedImageDiagnostics.get_last_decode_stats()`（可在 load options 里加 `"perf_log": true`）。

可选限制（仍可用）：

```gdscript
{
    "decode_mode": "stream",
    "max_width": 8192,
    "max_height": 8192,
    "max_frames": 2000,
    "max_input_bytes": 50 * 1024 * 1024,
    "max_memory_bytes": 256 * 1024 * 1024,
}
```

---

## 6. StoryTavern 落地建议

对照当前集成（`probe` → `load_from_file` → `AnimatedImagePlayer` / backdrop）：

1. **Library 行**：只用 `probe_*` + `load_poster_*`，不要对每个资产 `load_from_file` 全动画。  
2. **进入聊天 / 真正要播时**：再 `load_from_file`（STREAM）。  
3. **CHARX / 导出 / 转码**：`decode_mode: "eager"` 或 `ensure_eager()`。  
4. **GIF**：probe 已不再 Slurp；播放路径 metadata 与 decoder 不再各 Slurp 一次 metadata。  
5. **APNG / WebP**：STREAM 为真增量 + ring-buffer，播第 2 帧不应再 OOM/卡死级全展开。

旧 `GodotGifAdapter`（纯 `GIFTexture`/`GIFPlayer`）仍可作为 GIF 对照；统一槽位在 STREAM 修好后应接近该流畅度。

---

## 7. Encoder / Metadata / 导入

- `AnimatedImageEncoder.encode_*_from_animated` 会先 `ensure_eager()`  
- `AnimatedImageTranscoder.convert` 强制 eager 解码  
- 编辑器「Animated Image」导入保存 `.res` 使用 eager（全帧写入 storage）  
- 静态 `.png` / `.webp` 默认仍走 Godot Texture 导入（本插件 importer 优先级较低）

---

## 8. 版本与构建

```bat
cd godot-animated-image
scons platform=windows target=template_debug
scons platform=windows target=template_release
```

把 `addons/godot_animated_image/` 同步到目标工程后**重启 Godot**。  
若出现 Error 1114，确认 DLL 为本次构建产物且未被旧进程锁定。
