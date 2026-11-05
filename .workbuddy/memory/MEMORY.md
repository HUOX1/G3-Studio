# G3-Studio 项目备忘

## 产品定位
- 私人数字收藏终端（Windows），定位是"收藏柜/橱窗"而非普通资源管理器
- 技术栈：Godot 4.7.2（3D 前端，g3_frontend）+ Python Core（SQLite/扫描/WebSocket，g3_core）
- 收藏分区：Games（主 vertical slice）、Movies（TMDB）、Comics、MUSIC、Fonts、Themes
- 游戏源扫描器：Steam / GOG / Epic / PSN / Rockstar / Uplay / 模拟器；封面来自 SteamGridDB
- UI 特征：3D 游戏盒四槽轮播橱窗、自绘标题栏、hover 展开导航抽屉、约 20 个自研 gdshader
- 设计文档 docs/design/G3_Archive_Space_02.md：曾参考 RhineLabUI 做"游戏藏品室"空间实验，后回退为占位
- 动效已有规范：指数趋近 ~167ms/95%、减少动态模式、Esc 层级处理、长标题三行+tooltip

## 素材目录契约（2026-10-29 定案）
- 游戏素材目录 = covers/games/<标题>[ (后缀)]，UUID 仅作数据库主键/内部 ID，禁止当目录名；同名游戏用 (年份)/(平台)/短 ID 后缀，按 (created_at, id) 稳定分配
- 写入统一走 MediaAssetService.set_game_asset（原子替换+旧扩展名清理）；读取 = 标题目录优先、UUID 目录兜底（兜底仅为兼容，磁盘已无 UUID 目录）
- 改名 = 只读收集（collect）→ DB 更新 → 恢复写入新标题目录，旧目录不删；Steam 扫描器已注入 media 服务，「任意扩展名已存在即跳过」
- 历史遗留 UUID 目录已由用户手动清零并复刮验证（48 目录=48 游戏）；user 确认真实环境闭环

## UI/UX 咨询记录（2026-10-24）
- 用户在打磨 UI/UX，向其给出建议（3D 橱窗效率、分区交互语法统一、元数据健康度、启动主路径等）
- docs/目录截图/*.jpg 实际是资源管理器截图，不是软件 UI 截图；评审 UI 需用户提供真实运行截图
- Games 分区真实 UI（2026-10-24 截图）：左侧深色栏（搜索+彩色来源图标+游戏名平铺列表+底部"+"按钮，无分组），主区为 7 列统一封面网格（Steam library 风），主区无工具栏/排序/筛选，侧栏排序依据不明，未见悬停/选中态信息
