# G3 架构文档

覆盖版本: v0.6.5
Date: 2026-10-26（补充已核验源码实现）

> 本文档描述 G3 的分层、通信协议、数据模型、交互逻辑、视觉特效与核心算法实现。

---

## 1. 整体架构

G3 采用**前后端分离**架构：
- **前端**：Godot 4，负责 2D UI、3D 渲染（电影卡片轴）、交互逻辑与动画。
- **后端**：Python，负责 SQLite 数据存储、文件扫描、网络刮削、外部进程（mpv/游戏）监控。

双方通过**本地 WebSocket**（`127.0.0.1:8765`，协议版本 1）进行通信。前端使用 JSON 发送请求（带 `id` 对应响应），后端处理完成后返回结果或推送事件。

### 1.1 后端命令路由
后端核心入口为 `g3_core/backend_app.py` 的 `handle_command`，按 `command_type` 分发具体业务。
前端已完成主要请求职责拆分：`g3_frontend/scripts/backend_router.gd` 按请求 ID 路由响应，支持 latest-slot、过期/重复响应过滤和连接代次隔离；游戏、电影、系统、库扫描等业务分别由对应控制器管理。`main.gd` 负责根节点组装、UI 回调、模块协调，仍有 `legacy_response_received` 兼容分支；不能再把“上百个 `_pending_xxx_id` 全在 main 中”描述为当前架构。详细演变见 `G3_Main_Decoupling.md`。

---

## 2. 数据模型与路径

### 2.1 全局路径
所有数据存放于 `%LOCALAPPDATA%\G3`。

| 路径 | 说明 |
|---|---|
| `library.db` | SQLite 主数据库 |
| `settings.json` | 全局设置（显示模式、字体组别、库路径等） |
| `covers/` | 封面图（分 `movies/` 和 `games/`） |
| `cache/` | 自动抽帧、缩略图等缓存 |
| `fontsets/` | 字体组别配置 |
| `tmdb.json` / `sgdb.json` / `psn.json` | 各平台刮削配置 |

### 2.2 核心表结构
- `library_items`：主表，存 `title`、`media_type`（`game`/`movie`/`series`）、`source_path`、`library_scope`（`main`/`private`）、`watched_seconds`、`total_seconds`、`watched_complete`。
- `games`：游戏扩展（启动参数、游玩时长、平台、`steam_appid`、`psn_playtime_seconds`）。
- `game_metadata`：通用元数据（开发商、发行商、年份、类型、评分、tagline、截图等），电影和游戏共用。
- `movie_episodes`：剧集专属，存每集的季号、集号、视频路径、标题、简介。
- `emulators`：模拟器配置表。

**注意**：
- 所有涉及电影/剧集的 SQL，**必须带** `WHERE library_scope = ?`（防串库）。
- 所有路径**必须**统一为正斜杠（防 SQL 精确匹配失效）。

---

## 3. 电影板块

### 3.1 3D 卡片与轴
- **相机**：`Camera3D` 位于 `(0, 0, 7.2)`。
- **布局**：卡片宽度随封面自适应（3.0~4.6），高度固定 5.2，间距 0.6。列中心在屏幕 `18%` 处。
- **状态机**：
  - 选中卡：`Z = 1.4`，缩放 `1.12`。
  - 未选中卡：`Z = 0.5`，缩放 `1.0`。
  - 切换时，`_scroll_offset` 用 `lerp` 平滑追踪目标索引。
- **悬停倾斜**：鼠标靠近哪边，哪边凹下去。yaw 为 ±4°，pitch 为 ±3°。
- **X 坐标随 Z 实时重算**：保证卡片浮起后屏幕视觉位置不偏。

### 3.2 背景图系统
- **自动抽帧**：从视频 `15%~85%` 分 8 个桶，随机取 8 帧。
- **轮播与缓动**：每 7 秒换一张，1.2 秒 GPU 内交叉淡入（`mix`）。手动设置的背景图不轮播。
- **位置规则**：
  - 画幅 `aspect >= 2.1`：右对齐（左边缘贴卡片，右边缘贴屏幕）。
  - 其余画幅：居中于“卡片右边缘 → 屏幕右边缘”这段可用区。
- **缓存机制**：内存 LRU 缓存最多 8 部，缩略图缩小到 1280 宽。切走再切回用**墙钟时间戳**计算轮播索引。
- **高画幅视锥剔除修复**：上滑预览图时，shader 里用顶点偏移 `VERTEX.y += cull_offset_y` 欺骗引擎，保证 AABB 永远在视锥内。

### 3.3 信息区与隐藏层
- **固定比例**：标题固定屏高 `11%`，简介固定屏高 `80%`，元数据在标题下方。不受画幅切换影响。
- **隐藏层**：右下角有 220x140 热区。滚轮向下，预览图与简介上滑 `160px`，底部滑出隐藏层（显示 tagline）。标题原地淡出至 `0.15` 透明度。
- **鼠标分区**：鼠标在信息区（`x > 0.6 * vp.x` 且 `y > 0.5 * vp.y`）时，滚轮只滚简介，不切电影。

### 3.4 剧集与刮削
- **剧集抽屉**：悬停卡片右侧展开，按季分条。支持 `overview` 浮动窗（毛玻璃 + 光带，悬停 0.35s 触发）。
- **TMDB 刮削**：只填空不覆盖。每集标题采用“先精确匹配 season/episode，后按顺序线性兜底”两步法。
- **私库（品红库）**：
  - 长按导航栏电影图标 1.5s 切换。图标从底向上填充（`icon_fill.gdshader`）。
  - 独立主题色：品红（`(0.95, 0.22, 0.72)`）。
  - 隔离机制：独立的库路径、独立的封面文件夹、禁用 TMDB 刮削。
  - 渲染优化：私有库下关闭 glow，避免品红背景导致卡片发白。

---

## 4. 游戏板块

### 4.1 布局形态
- **左侧边栏**：宽 280。包含搜索（实时过滤）、排序（三态循环：名称、时长、最近游玩）、添加按钮。行高 28。
- **视觉分层（2026-10-30）**：
  - **三段底色**：顶部功能区与底部功能区同为 `#111923`，中部游戏列表 `#1A2635`；三段只靠色差分区，`_sep_line` 隐藏，不使用硬分割线。
  - **列表内阴影**：`sidebar_inner_shadow.gdshader`，覆盖层对齐列表带（`_sidebar_scroll.offset_top` → `-footer_h`），仅上/右/下三边（`left_weight = 0`），`strength 0.26`、`radius 22×ui_scale`、`falloff 2`；`mouse_filter = IGNORE`，固定在视口、不随滚动内容移动，顶部与底部功能区不受影响。
  - **菜单栏同源**：游戏板块的菜单栏底色由 `game_section` 的 `sidebar_surface_color_changed` 广播的"顶部实际合成色"接管（`window_chrome.set_bar_color()`），Hero 过渡中两者逐帧一致；其他板块仍沿用 `base.darkened(0.24)` 与主题色混色。
  - **海报墙底色**：`game_background.gdshader` 的 `top_color (0.1378, 0.1938, 0.2717)` / `bottom_color (0.1188, 0.1672, 0.2309)`，明度整体高于侧边栏三段，`glow_amount 0.045`、`edge_vignette 0.10`；主题染色只叠色相，不改亮度基准。
  - **右键菜单**：`game_menu_overlay.gd` 为挂在主 UI `CanvasLayer` 上的 Control 浮层（非 `PopupPanel`），复用 `glass_panel.gdshader`；`PopupPanel` 属嵌入式子窗口，`hint_screen_texture` 采样不到主场景画面，只能得到纯黑。整行悬停 0.12s 渐入，普通项 alpha 0.12、危险项 alpha 0.16。
  - **添加按钮**：悬停整体缩放 `1.04` / `0.15s`（中心枢轴），不参与布局；原 `dot_glow` 光晕层与空状态呼吸已移除。
- **右侧海报墙**：普通 `Control` 手动布局。
  - **分档规则**：宽 150（5-7列）、200（5-7列）、290（6-8列）。根据窗口宽度自适应。
  - **弹簧物理**：不瞬移，公式为 `vel += delta_pos * K * delta`。刚度 `300.0`，阻尼 `16.0`，最大速度 `1800.0`。
  - **阴影**：悬停时阴影 `size` 变大、`alpha` 变淡，用 lerp 平滑过渡。
  - **悬停放大**：放大 `1.03` 倍，pivot 在底边中心（往上涨，底边不动）。
  - **封面加载**：`game_section.gd` 限制 2 个并发工作项；标准图片最长边缩至 768，已完成纹理每帧最多应用 1 张；加载队列优先视口内、邻近区域，再到其他卡片。动态格式走扩展加载路径及兼容回退。
  - **封面进入**：已加载且可见的封面利用 `game_card_flip.gdshader` 进行 Y 轴透视入场（约 -78°→0°，0.85s），每帧至多启动一个新的动画调度，按 120ms 间隔排程；首次纹理应用后的首个可见入场延后一帧。封面加载/入场未结束时，卡片布局弹簧暂不接管对应变换。
- **详情页**：
  - 左侧 62% 标题/按钮/截图/元数据，右侧 38% 简介。
  - 面板初始顶边屏高 `40%`，滚轮升起，到 `10%` 后内部滚动（`ScrollContainer` 设 `IGNORE` 手动接管）。
  - LOGO 从起点 `(400x150)` 漂移到右栏 `(560x210)`。

### 4.2 启动与监视
- **三种模式**：直接 EXE、模拟器（占位符 `{content}` 替换）、启动器。
- **UAC 提权**：遇到需管理员权限的 exe，自动转 `ShellExecuteW(runas)`，拿不到句柄则靠 `monitor_exe` 轮询。
- **进程监控（三阶段）**：
  1. 等进程出现（最长 15 秒）。
  2. 等进程消失（每 1.5 秒查一次）。
  3. 消失后再等 2 秒确认。
- **衍生进程**：启动器退出后，找同前缀的衍生进程继续监控。
- **空壳游戏**：无 `launch_exe` 且无 `source_path`（或模拟器缺内容）的游戏视为空壳，排在海报墙末尾。当前海报墙使用 `game_card_flip.gdshader` 同时处理透视翻转和饱和度，空壳饱和度目标为 `0.15`，悬停时渐变回彩；不能再把 `game_card_gray.gdshader` 当作当前海报墙的实际引用材质。

### 4.3 批量模式与文本导入
- **批量模式**：按 `B` 键进入。卡片左上角出勾选框，选中亮青边呼吸。支持全选、批量删除、批量 Steam 刮削（取第一个搜索结果）。
- **文本粘贴导入**：支持中英文前缀识别（“标题：”、“Developer：”等），自动多行续接简介。可直接创建空壳，或更新已有条目。

### 4.4 字体组别系统
- **配置与来源**：从 Windows HKLM/HKCU 枚举系统字体；字体组别保存在 `fontsets/<id>.json`，支持新建、复制、重命名、删除、切换。
- **字体排版策略**：布局缩放与文字缩放分轨（`ui_scale` / `font_scale`），后续排版参数若无可核对的源码依据，不在文档中推定。
- 分为 `movies` 和 `games` 两个 scope，各自独立保存。
- **编辑器**：嵌套在 System 页。三级导航：主设置 -> 字体总览 -> 编辑器。防抖 0.1s 实时预览。
- **下拉框限制**：只显示中文字体和白名单字体。**必须设置 `fit_to_longest_item = false`**，防止超长字体名撑爆 UI。

---

## 5. 扫描与刮削器

### 5.1 本地库扫描
统一在 `library_scan_dialog.gd` 中，7 个 Tab，独立缓存。

- **Steam**：读 VDF，10 秒轮询本地时长，只增不减。从缓存搬 `600x900`、Hero、Logo 封面。
- **GOG**：读注册表，直连 exe。
- **Epic**：读 JSON，排除 `engine` 等目录。自动找主 exe 启动（避开 Bootstrapper）。
- **Uplay**：读注册表，自动找主 exe。
- **Rockstar**：读注册表。**只扫描入库，不保证启动监视**（主 exe 常被 Social Club 屏蔽）。
- **PSN**：`psnawp` 库通过 `npsso` 认证。可用本地 `psn_override.json` 兜底。时长存独立的 `psn_playtime_seconds` 字段，与 G3 自己计时分开。名称含 Demo/Trial 等关键词的会被过滤。
- **模拟器**：找 `PS3_GAME` 文件夹（传目录给 RPCS3）或 `.cue` 镜像。

### 5.2 网络刮削
- **Steam**：只抓短简介。Hero 和截图并发下载（最多 8 张，6 路并发）。
- **SGDB**：12 路并发下载缩略图。动态图用原图转 PNG 缩到 320。
- **TMDB**：海报列表按评分降序，6 路并发下载 `w185` 缩略图。应用时下 `w500` 大图。
- **网络方案**：TMDB 采用修改 Hosts 直连，不走代理。

---

## 6. 全局外壳与 UI 规范

### 6.1 窗口与缩放
- **双轨缩放**：布局尺寸用 `ui_scale`（下限 0.62），字号用 `font_scale`（下限 0.90），分别取 clamp。
- **全屏**：通过 `DisplayServer.window_set_mode(WINDOW_MODE_FULLSCREEN)` 实现，全屏隐藏自绘窗口栏。F11 切换。
- **窗口 16:9**：窗口模式下强制锁定 16:9，最小尺寸 1244×700。
- **UI 缩放基准**：动态加入 System 页的节点，只在第一次记录 `base_min_size`，避免窗口改变时二次缩放。

### 6.2 动画与交互
- **导航抽屉**：顶部悬停展开，光晕使用 `glow_line.gdshader`（`blend_add`，呼吸时只变亮度不改形状）。导航发出 `opened_changed` 供卡片先上下让位；随后在展开动画初段发出 `drawer_revealed` 触发受影响的左侧卡片横向弹簧让位，非等抽屉完全展开才移动。
- **板块切换**：黑场过渡（0.25s 淡入 + 0.35s 淡出）。
- **播放退出**：电影调用外部 mpv（带 `--ontop`）。启动游戏或播放电影时，前端会延迟 0.6 秒将 `render_loop_enabled` 设为 `false`。收到 `exited` 事件后恢复。不最小化窗口，避免桌面闪。

### 6.3 WebSocket 通信
Godot `WebSocketPeer` 默认接收缓冲 64KB，容易导致大列表响应报 1009 错误。必须在 `connect_to_url` 之前设置：
```gdscript
_socket.inbound_buffer_size = 8 * 1024 * 1024 # 8MB
```

---

## 7. 全局铁律（违反必出 Bug）

| 铁律 | 说明 |
|---|---|
| **路径正斜杠** | 所有磁盘路径统一转为 `/`，禁止出现 `\`，否则 SQLite 精确匹配会失效（Windows 特有坑） |
| **电影私有库隔离** | 所有涉及 `library_items` 中电影/剧集的 SQL，必须带 `WHERE library_scope = ?`，防止串库 |
| **只填空不覆盖** | 所有刮削器（TMDB / Steam / SGDB）写库时，只填空字段，不覆盖用户手填的内容 |
| **Options 下拉框** | Godot 的 `OptionButton` 放入固定宽度容器时，**必须**设置 `fit_to_longest_item = false`，否则会被超长字体名撑爆屏幕 |
| **数据库迁移** | 修改表结构时，必须在 `database.py` 的 `_migrate()` 里用 `PRAGMA table_info` 检查并 `ALTER TABLE`，绝对不要手动改数据库 |
| **UI 缩放双轨** | 字号缩放用 `font_scale`（下限 0.90），布局间距用 `ui_scale`（下限 0.62），二者不要混用 |
| **WSS 握手** | 前端设置 WebSocket 缓冲时，必须在 `connect_to_url` 之前设置 `inbound_buffer_size = 8MB`，否则列表响应超过 64KB 会导致 1009 错误断开 |

---

## 8. 2026-10-22～23 游戏进程监视与详情页补充

### 8.1 Epic 游戏启动与进程交接

- Epic 通过 `game_runtime.py` 优先直接启动已配置的游戏 EXE；`RunningGame` 携带 `launch_pid`、`install_dir`、`monitor_exe` 等信息。
- `backend_app.py` 的监视任务通过 `game_process_probe.py` 匹配进程并推送 `game.running` / `game.exited`；前端收到事件后暂停或恢复 Godot 渲染。
- Sifu 冷启动实测发现：首次 `Sifu-Win64-Shipping.exe` PID 消失后，Epic 验证尚未完成，旧版 3 秒空档会导致过早发送 `game.exited`。
- Epic 增加**有界的进程交接宽限**（45 秒），并在主监视进程连续存活约 10 秒后回到正常的短退出宽限（3 秒）；交接期间允许结合安装目录匹配新进程，并过滤已知平台辅助进程。其他平台保持原有策略。
- **涉及文件**：`g3_core/services/game_runtime.py`、`g3_core/backend_app.py`、进程检测相关服务文件。
- 验收边界：用户反馈已修复 Epic 冷启动提前恢复渲染；其他平台的完整回归测试仍需按平台执行。Rockstar 仅扫描入库的定位不变。

### 8.2 PlayStation SVG 加载

- 原始 SVG 不再依赖 `ResourceLoader.load()` 直接读取；改用文件字节缓冲区经 Godot `Image.load_svg_from_buffer()` 解码并生成纹理。
- 该修复不改变 PSN 数据字段、认证或扫描流程。具体修改文件以项目源码差异为准。

### 8.3 游戏详情页布局与动画

- **首次进入布局**：容器尺寸稳定后再同步 LOGO 留白及详情页位置，避免首次进入时简介、元数据偏高。
- **光盘退出**：`dvd_launch_button.gd` 的光盘复位采用 Tween 退出过渡，避免瞬移。
- **游戏时间**：跟随面板展开或滚动进度线性渐显/渐隐；没有内部可滚动距离时改由面板展开进度驱动，避免一直透明。
- **图标对齐**：游戏时间采用 `Label` 对齐字体度量；元数据图标按第一行文字对齐，减少窗口/全屏切换时的垂直漂移。
- **截图缩略图**：缩略图宽度以大图实际显示宽度而非左栏宽度计算，缩略图容器居中，并在切换截图时刷新尺寸；尚未收到最终视觉验收反馈。
- **涉及文件**：`g3_frontend/scripts/game_detail_view.gd`、`g3_frontend/scripts/dvd_launch_button.gd`。
- **启动装置实验隔离**：COMICS 原图标对比页复用为 Disc Loader 实验页，使用独立的 `disc_loader_lab.gd` 与 `disc_loader_experiment_button.gd`，只在详情页布局模拟中预览机械面板和光盘吸入 / 读取 / 退盘演示；托盘与光盘第二阶段同步收回，并渐显机身内腔轮廓；不调用真实启动链路，不改正式 `game_detail_view.gd` / `dvd_launch_button.gd`。实验页接收主程序转发的 Hero 主题调色板 accent，驱动接口灯与状态指示灯染色。

### 8.4 修改边界

- UI 布局遵循现有双轨缩放；避免为单一分辨率写死偏移量。
- 进程监视修复不应修改前端 `game.running` / `game.exited` 协议，也不应误将 Epic/EOS 辅助进程当作游戏。
- 详情页修改不触及 Epic 监视、电影播放器、字体配置、DVD 以外的启动逻辑。


## 9. Git 补丁注入器（工具链）

- **本次 ZIP 可核验文件**：`Apply-G3NavSpringFix_Diagnostic.ps1` 与配套 BAT；历史文档所述 `Apply-G3NavSpringFix.ps1` 原版不在本次 ZIP 内，不据此断言原版与诊断版完全相同。
- **项目识别**：保留固定的项目标志文件用于寻找 G3 根目录，不再将它们当作允许修改文件的唯一白名单。
- **作用域识别**：从 `diff --git` 文件头读取真实目标路径；支持带 Git 转义的路径，按补丁涉及文件进行暂存、检查和回写。
- **安全边界**：阻止绝对路径、`..` 路径穿越及受保护目录；识别非 UTF-8 / 二进制文件并跳过文本行尾规范化。
- **使用约束**：注入器处理的 Git diff 必须带合法 `diff --git` 文件头；新增、删除文件及二进制场景仍需在 Windows 环境全面回归。

## 10. 游戏封面主题服务（第一阶段）

- **职责边界**：`g3_core/services/game_theme.py` 的 `GameThemeService` 根据当前游戏 Hero/封面生成临时语义调色板，仅用于游戏详情和窗口视觉联动；它不是用户可选主题系统。G3 已移除应用级 ThemeService 与主题切换入口。
- **调色板角色**：`accent`、`secondary`、`surface`、`ambient`、`shadow`。UI 消费者应使用语义角色，不自行分析封面或复制调色逻辑。
- **取色算法**：封面缩小至最多 64×64，动画封面取首帧；按透明度、感知亮度和饱和度过滤像素，以加权循环色相分桶提取主色，降低 RGB 分桶把相近色相拆散的问题。衍生 `surface`、`ambient`、`shadow` 时使用 OKLab 控制近似恒定的感知明度与受限色度，避免主题变化主要表现为整体变亮。低彩度、缺失或不可解码的封面回退到中性深灰蓝调色板。
- **缓存**：调色板写入 `%LOCALAPPDATA%/G3/cache/game_theme_palettes/`。缓存记录按规范化封面路径分键，并校验文件大小、纳秒修改时间、缓存 schema 和算法版本；封面替换时可显式失效。无需数据库迁移。
- **后端接口**：`game.theme.palette` 接受已有游戏 `id`，由后端解析其当前封面并返回 `{item_id, palette}`；封面读取和颜色分析在工作线程执行。详情页与侧边栏已消费 `surface` / `ambient`；卡片悬停阴影仍待接入同一来源。
- **UI 应用约束**：调色板 v2 用 OKLab 为深色语义表面控制近似恒定的感知明度，UI 再以受控混合比例应用色相。详情页进入/退出与侧边栏恢复由第二阶段控制器管理；Windows 实机的最终色彩效果仍需验收。
- **涉及文件**：`g3_core/services/game_theme.py`、`g3_core/backend_app.py`、`g3_tests/test_game_theme_service.py`、`g3_tests/test_backend_app.py`。

## 11. 游戏封面主题接入（第二阶段）

- **动态调色板状态所有权**：`g3_frontend/scripts/game_theme_controller.gd` 是前端游戏主题状态控制器，通过 `backend_router.gd` 调用第一阶段 `game.theme.palette` 接口；它负责激活游戏 ID、拒绝过期异步响应，并在详情页关闭时清理当前主题。
- **消费边界**：`game_section.gd` 将同一调色板分发给游戏左侧列表背景和 `game_detail_view.gd` 的面板渐变 Shader；UI 不直接读取封面，也不重复提取颜色。
- **视觉强度**：仅将调色板 `colors.surface` 以低比例混入现有侧栏/详情面板底色，并使用 340ms Sine In-Out 过渡；默认颜色、字体颜色、选中/错误语义色、布局和卡片悬停参数不变。
- **恢复与竞态**：关闭详情页会递增请求代次并恢复中性配色；旧请求响应不会重新染色已关闭的详情页。低彩度/缺失封面返回 `status=fallback` 时保留原始中性配色。
- **范围**：本阶段只接入游戏详情视图和游戏板块左侧列表背景；顶端导航抽屉、卡片悬停阴影和其他模块尚未接入。
- **验证边界**：需在用户 Windows/Godot 环境检查颜色过渡、退出恢复、快速开关详情页以及缺失封面回退；静态补丁检查不能替代实机视觉验收。


## 12. Hero 驱动的全局游戏氛围主题（第三阶段）

- **取色优先级**：`game.theme.palette` 优先使用游戏数据中的 `backdrop`（Hero）资源；Hero 不存在、不可解码或低彩度时回退到封面；两者均不可用时返回中性调色板。动态取色采样尺寸提升为 96×96，算法版本升级到 v3，旧缓存自动失效。
- **缓存与资源更新**：调色板仍按规范化资源路径、文件大小、纳秒修改时间、schema 与算法版本缓存。SteamGridDB Hero 替换时显式失效该资源缓存。
- **详情面板**：`panel_gradient.gdshader` 支持主题顶部色、底部环境色和强度；详情页以暗化后的 Hero 主色作为上部色调，向 ambient/surface 过渡，保持现有面板 alpha 渐变和布局。
- **侧栏与添加按钮**：游戏侧栏新增透明上下渐变叠层；底部添加游戏区域跟随主题色轻微染色，添加按钮光晕的颜色从默认蓝色平滑过渡到 Hero 主色。所有过渡约 380ms，并在快速切换时终止旧 Tween 后从当前值继续。
- **窗口标题栏**：`window_chrome.gd` 增加独立的游戏主题色过渡；只轻微染色标题栏背景，保留应用主题文字、窗口按钮和语义状态。退出详情页恢复原始应用主题色。
- **状态恢复**：主题控制器继续负责过期响应过滤；主题清除时详情面板、侧栏渐变、添加按钮光晕和窗口标题栏均回到中性默认状态。
- **涉及文件**：`g3_core/services/game_theme.py`、`g3_core/backend_app.py`、`g3_frontend/scripts/game_section.gd`、`g3_frontend/scripts/game_detail_view.gd`、`g3_frontend/shaders/panel_gradient.gdshader`、`g3_frontend/scripts/window_chrome.gd`、`g3_frontend/scripts/main.gd` 及相关定向测试。
- **验证边界**：主题服务与后端定向测试通过；Godot 脚本/Shader 运行时编译、Windows 注入器应用和实际视觉强度仍需用户本机验收。
