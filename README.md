# G3

> 运行在 Windows 上的私人数字收藏终端。把游戏库和影视库收进同一个 3D 界面。

当前版本 **`v0.6.5.0`** · Godot 4.7.2 + Python 3.11+

---

## 这是什么

G3 是一个本地单机的个人收藏管理工具，不联网、不登录、不上传。数据全部存在本机 SQLite 里。

**游戏板块**
- 扫描 Steam / GOG / Epic / Uplay / Rockstar / PSN 六类游戏库，读注册表、`libraryfolders.vdf`、`appmanifest`、`LauncherInstalled.dat` 等原始数据
- 扫描模拟器目录（PS3 文件夹、PS1 光盘镜像）
- 3D 盒体海报墙，弹簧物理、悬停放大、动图封面（webp / gif / apng）
- 三种启动方式：直连 exe / 启动器 / 模拟器，支持 `{content}` 占位符、UAC 提升、进程监视
- Hero 取色生成语义调色板，整个界面的主题色跟着当前游戏变

**电影板块**
- 左侧 3D 卡片轴，选中卡 Z 轴前浮；悬停倾斜 yaw ±4° / pitch ±3°
- 背景图自动抽帧：从视频 15%~85% 分 8 桶各取一帧，每 7 秒 GPU 内交叉淡入
- TMDB 刮削（只填空不覆盖手填），剧集按季分条、每集独立标题与简介
- 双击调用 mpv 全屏无边框播放，退出后恢复 G3

**私有库**
- `library_scope = 'private'` 与主库物理隔离，互不可见
- 独立品红主题、独立库路径、独立封面文件夹、TMDB 刮削禁用

---

## 技术架构

| 层 | 技术 | 职责 |
|---|---|---|
| 前端 | Godot 4.7.2（GDScript） | 2D UI、3D 卡片与盒体渲染、动画、交互逻辑 |
| 后端 | Python 3.11+ | SQLite 存储、文件扫描、网络刮削、外部进程监控 |
| 通信 | 本地 WebSocket | `127.0.0.1:8765`，协议版本 1，JSON 请求带 `id` 对应响应 |

前后端完全解耦：前端 `backend_router.gd` 按请求 ID 路由响应，支持 latest-slot、过期响应过滤和连接代次隔离；游戏、电影、系统、库扫描各自有独立控制器。

**核心数据表**

| 表 | 用途 |
|---|---|
| `library_items` | 主表：标题、媒体类型、源路径、库归属、观看时长 |
| `games` | 游戏扩展：启动参数、平台、`steam_appid`、PSN 时长 |
| `game_metadata` | 通用元数据，电影与游戏共用 |
| `movie_episodes` | 剧集：季号、集号、视频路径、标题、简介 |
| `emulators` | 模拟器配置 |

---

## 快速开始

```bat
setup_windows.bat      :: 首次安装依赖
run_windows.vbs        :: 正常启动（无控制台窗口）
run_windows_debug.bat  :: 调试启动（保留日志输出）
```

首次启动如果找不到 Godot，会要求手动指定 **Godot 4.7.2 Standard** 可执行文件。

**数据目录**：`%LOCALAPPDATA%\G3`

| 路径 | 内容 |
|---|---|
| `library.db` | SQLite 主数据库 |
| `settings.json` | 全局设置（显示模式、字体、库路径） |
| `covers/` | 封面图，分 `movies/` 与 `games/` |
| `cache/` | 自动抽帧与缩略图缓存 |
| `fontsets/` | 字体组别配置 |

---

## 项目结构

```
g3_core/          Python 后端
  backend_app.py    命令路由入口（handle_command）
  database.py       SQLite 访问
  websocket_server.py
  services/         扫描器、刮削器、启动器、主题取色
g3_frontend/      Godot 前端
  main.tscn         根场景
  scripts/          控制器、视图构建器
  shaders/          背景、毛玻璃、封面特效
  assets/models/    3D 盒体资源
g3_launcher/      启动器：环境发现与进程拉起
g3_tests/         pytest 源码契约测试
g3_tools/         诊断与工具脚本
docs/             架构、功能状态、开发历史
```

---

## 文档

| 文档 | 内容 |
|---|---|
| [`docs/README.md`](docs/README.md) | 文档索引、协作模式、日志更新约定 |
| [`docs/architecture.md`](docs/architecture.md) | 分层、通信协议、数据模型、3D 轴算法、UI 规范 |
| [`docs/feature-status.md`](docs/feature-status.md) | 功能地图与验收状态，末尾有「建议下一步」 |
| [`docs/history.md`](docs/history.md) | v0.6.0 → v0.6.5 完整演进史与设计决策复盘 |

想知道某个决策为什么这么定、踩过什么坑，看 `history.md` 对应时间线。

---

## 开发约定

- **缩进统一 Tab**。Notepad++ 与 VSCode 混用曾导致 Tab/空格不一致，破坏过 Python 缩进
- **所有路径统一正斜杠**，否则 SQL 精确匹配失效
- **电影/剧集的 SQL 必须带 `WHERE library_scope = ?`**，防止私库串到主库
- `Control.scale` 只改变视觉变换，不能当父容器的布局尺寸用
- 节点迁移到新父容器后，必须区分全局坐标与局部坐标
- 补丁格式检查通过 ≠ Godot 实机运行通过

---

## 命名

- **G1** —— v0.5 及更早的 Qt / PySide6 原型机，保留作为视觉与交互设计参考
- **G3** —— 当前 Godot + Python 架构主线
- 名字取自假面骑士亚极陀的二骑 G3，成熟后计划改名 **G3-X**
