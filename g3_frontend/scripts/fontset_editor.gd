extends VBoxContainer
class_name G3FontsetEditor

signal action_requested(action: String, payload: Dictionary)

const SCOPE_MOVIES: String = "movies"
const SCOPE_GAMES: String = "games"

const FIELD_KEYS_BY_SCOPE: Dictionary = {
	SCOPE_MOVIES: [
		"movie_title", "movie_year", "movie_meta",
		"movie_desc", "movie_tagline", "ui_default",
	],
	SCOPE_GAMES: [
		"game_title", "game_meta", "game_playtime",
		"game_desc", "game_sidebar", "ui_default",
	],
}

const FIELD_LABELS: Dictionary = {
	"movie_title": "电影标题",
	"movie_year": "电影年份",
	"movie_meta": "元数据行",
	"movie_desc": "电影简介",
	"movie_tagline": "标语（隐藏层）",
	"ui_default": "全局 UI",
	"game_title": "游戏标题",
	"game_meta": "游戏元数据",
	"game_playtime": "游玩时长",
	"game_desc": "游戏简介",
	"game_sidebar": "侧边栏",
}

const DEFAULT_SIZES: Dictionary = {
	"movie_title": 34,
	"movie_year": 14,
	"movie_meta": 14,
	"movie_desc": 16,
	"movie_tagline": 22,
	"ui_default": 15,
	"game_title": 40,
	"game_meta": 13,
	"game_playtime": 14,
	"game_desc": 15,
	"game_sidebar": 14,
}

# ── 电影预览文本 ──
const PREV_MOVIE_TOP1: String = "1982"
const PREV_MOVIE_TITLE: String = "银翼杀手 2049"
const PREV_MOVIE_TOP3: String = "▸ 科幻, 剧情 · ◷ 1小时57分 · ★ 7.9"
const PREV_MOVIE_DESC: String = "一个科技高度发达却因城市与社会凋敝而黯淡的未来，侦探瑞克·戴克奉命追捕叛逃的凶残复制人。"
const PREV_MOVIE_MID: String = "“我所见过的事物，你们人类绝对无法置信。”"
const PREV_MOVIE_UI: String = "操作说明：滚轮 / ← → 选择    单击预览    双击播放"

# ── 游戏预览文本 ──
const PREV_GAME_TOP1: String = "游玩时长：12.3 小时"
const PREV_GAME_TITLE: String = "雨世界"
const PREV_GAME_TOP3: String = "开发商：Videocult  ·  发行：Adult Swim  ·  2017  ·  PC"
const PREV_GAME_DESC: String = "你是蛞蝓猫，一只在荒芜的工业废墟中挣扎求生的软体动物。要躲过捕食者，寻找食物和庇护所。"
const PREV_GAME_MID: String = "侧边栏显示：雨世界"
const PREV_GAME_UI: String = "操作说明：滚轮 / ← → 选择    单击预览    双击播放"

const LABEL_W: float = 100.0
const FONT_W: float = 200.0
const SPIN_W: float = 90.0
const SEP: float = 10.0
const SPLIT_GAP: float = 28.0
const PREVIEW_W: float = 680.0

# 白名单关键词：字体名"包含"任一条即通过。
# 用包含匹配而非精确匹配，是为了兼容同字体的不同字重后缀
# （如 "Noto Sans SC Medium" / "Source Han Serif SC Heavy"）
const FONT_NAME_KEYWORDS: Array[String] = [
	"Microsoft YaHei",
	"Microsoft JhengHei",
	"DengXian",
	"SimHei",
	"SimSun",
	"KaiTi",
	"FangSong",
	"MingLiU",
	"PMingLiU",
	# 思源黑体（Adobe 版 + Google 版）
	"Noto Sans SC",
	"Noto Sans CJK",
	"Source Han Sans",
	# 思源宋体（Adobe 版 + Google 版）
	"Noto Serif SC",
	"Noto Serif CJK",
	"Source Han Serif",
	# 霞鹜
	"LXGW Bright",
	"LXGW WenKai",
]

var _font_manager: Node
var _system_fonts: Array = []

var _current_scope: String = SCOPE_MOVIES
var _current_id: String = "default"
var _current_fields: Dictionary = {}
var _dirty: bool = false
var _preview_timer: Timer = null

# UI 节点
var _scope_label: Label
var _name_field: LineEdit
var _fields_column: VBoxContainer
var _field_rows: Dictionary = {}   # key -> {font_dropdown, size_spin}
var _status_label: Label
var _btn_save: Button
var _btn_new: Button
var _btn_copy: Button
var _btn_rename: Button
var _btn_delete: Button

# 预览节点
var _prev_top1: Label
var _prev_title: Label
var _prev_top3: Label
var _prev_desc: Label
var _prev_mid: Label
var _prev_ui: Label

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_build_ui()

	_preview_timer = Timer.new()
	_preview_timer.wait_time = 0.1
	_preview_timer.one_shot = true
	_preview_timer.timeout.connect(_update_preview)
	add_child(_preview_timer)	

func set_font_manager(fm: Node) -> void:
	_font_manager = fm

func set_system_fonts(fonts: Array) -> void:
	_system_fonts = fonts
	for key in _field_rows.keys():
		_rebuild_font_dropdown(key)

# ──────────────── UI 构建 ────────────────

func _build_ui() -> void:
	# 组别名称
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", int(SEP))
	name_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(name_row)
	var name_label := Label.new()
	name_label.text = "组别名称"
	name_label.custom_minimum_size.x = LABEL_W
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_label)
	_name_field = LineEdit.new()
	_name_field.custom_minimum_size.x = FONT_W + SPIN_W + SEP
	_name_field.size_flags_horizontal = Control.SIZE_FILL
	_name_field.text_changed.connect(func(_t): _mark_dirty())
	name_row.add_child(_name_field)

	# 适用版块（只读显示，由 System 页决定打开哪个 scope）
	var scope_row := HBoxContainer.new()
	scope_row.add_theme_constant_override("separation", int(SEP))
	scope_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(scope_row)
	var scope_key := Label.new()
	scope_key.text = "适用版块"
	scope_key.custom_minimum_size.x = LABEL_W
	scope_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scope_row.add_child(scope_key)
	_scope_label = Label.new()
	_scope_label.add_theme_font_size_override("font_size", 14)
	_scope_label.add_theme_color_override("font_color", Color(0.88, 0.72, 0.45))
	_scope_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scope_row.add_child(_scope_label)

	# 操作按钮
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	action_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(action_row)
	_btn_new = Button.new()
	_btn_new.text = "新建"
	_btn_new.pressed.connect(_on_new_pressed)
	action_row.add_child(_btn_new)
	_btn_copy = Button.new()
	_btn_copy.text = "复制"
	_btn_copy.pressed.connect(_on_copy_pressed)
	action_row.add_child(_btn_copy)
	_btn_rename = Button.new()
	_btn_rename.text = "重命名"
	_btn_rename.pressed.connect(_on_rename_pressed)
	action_row.add_child(_btn_rename)
	_btn_delete = Button.new()
	_btn_delete.text = "删除"
	_btn_delete.pressed.connect(_on_delete_pressed)
	action_row.add_child(_btn_delete)

	# 主体左右分栏
	var hsplit := HBoxContainer.new()
	hsplit.add_theme_constant_override("separation", int(SPLIT_GAP))
	hsplit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hsplit.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(hsplit)

	# ── 左栏 ──
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 6)
	left_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hsplit.add_child(left_col)

	_fields_column = VBoxContainer.new()
	_fields_column.add_theme_constant_override("separation", 6)
	_fields_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_col.add_child(_fields_column)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 10)
	save_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_col.add_child(save_row)
	_btn_save = Button.new()
	_btn_save.text = "保存此组别"
	_btn_save.custom_minimum_size.x = 160.0
	_btn_save.disabled = true
	_btn_save.pressed.connect(_on_save_pressed)
	save_row.add_child(_btn_save)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.clip_text = true
	save_row.add_child(_status_label)

	# ── 右栏：预览 ──
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hsplit.add_child(right_col)

	var preview_head := Label.new()
	preview_head.text = "预览"
	preview_head.add_theme_font_size_override("font_size", 12)
	preview_head.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	right_col.add_child(preview_head)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(PREVIEW_W, 420.0)
	preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.03, 0.09, 0.12, 0.72)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 14.0
	ps.content_margin_right = 14.0
	ps.content_margin_top = 14.0
	ps.content_margin_bottom = 14.0
	preview_panel.add_theme_stylebox_override("panel", ps)
	right_col.add_child(preview_panel)

	var preview_vbox := VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 4)
	preview_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(preview_vbox)

	var inner_w: float = PREVIEW_W - 28.0

	var top_group := VBoxContainer.new()
	top_group.add_theme_constant_override("separation", 4)
	top_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_vbox.add_child(top_group)

	_prev_top1 = _make_preview_label("", HORIZONTAL_ALIGNMENT_RIGHT, inner_w)
	top_group.add_child(_prev_top1)
	_prev_title = _make_preview_label("", HORIZONTAL_ALIGNMENT_RIGHT, inner_w)
	top_group.add_child(_prev_title)
	_prev_top3 = _make_preview_label("", HORIZONTAL_ALIGNMENT_RIGHT, inner_w)
	top_group.add_child(_prev_top3)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_vbox.add_child(spacer)

	var bottom_group := VBoxContainer.new()
	bottom_group.add_theme_constant_override("separation", 6)
	bottom_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_vbox.add_child(bottom_group)

	_prev_desc = _make_preview_label("", HORIZONTAL_ALIGNMENT_LEFT, inner_w)
	bottom_group.add_child(_prev_desc)
	_prev_mid = _make_preview_label("", HORIZONTAL_ALIGNMENT_LEFT, inner_w)
	bottom_group.add_child(_prev_mid)
	_prev_ui = _make_preview_label("", HORIZONTAL_ALIGNMENT_LEFT, inner_w)
	bottom_group.add_child(_prev_ui)

	await get_tree().process_frame
	await get_tree().process_frame
	_update_preview()

func _make_preview_label(text: String, align: int, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

# ──────────────── 对外 API ────────────────

# main 调用：scope + 数据
func open_for(scope: String, fontset: Dictionary) -> void:
	_current_scope = scope if FIELD_KEYS_BY_SCOPE.has(scope) else SCOPE_MOVIES
	_current_id = str(fontset.get("id", "default"))

	_current_fields.clear()
	var raw_fields = fontset.get("fields", {})
	if not (raw_fields is Dictionary):
		raw_fields = {}
	var keys: Array = FIELD_KEYS_BY_SCOPE[_current_scope]
	for key in keys:
		var entry = raw_fields.get(key, {})
		if not (entry is Dictionary):
			entry = {}
		_current_fields[key] = {
			"font_path": str(entry.get("font_path", "")),
			"font_size": int(entry.get("font_size", DEFAULT_SIZES.get(key, 14))),
		}

	_scope_label.text = "电影" if _current_scope == SCOPE_MOVIES else "游戏"
	_name_field.text = str(fontset.get("name", ""))
	_name_field.editable = (_current_id != "default")

	_rebuild_fields()
	_apply_preview_text_for_scope()
	_dirty = false
	_update_buttons_state()
	_update_preview()
	_status_label.text = ""

# 兼容旧 API（main 里旧调用仍能用）
func apply_fontset_data(fontset: Dictionary) -> void:
	var scope: String = str(fontset.get("scope", SCOPE_MOVIES))
	open_for(scope, fontset)

func _rebuild_fields() -> void:
	for child in _fields_column.get_children():
		_fields_column.remove_child(child)
		child.queue_free()
	_field_rows.clear()

	var keys: Array = FIELD_KEYS_BY_SCOPE[_current_scope]
	for key in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(SEP))
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_fields_column.add_child(row)

		var label := Label.new()
		label.text = str(FIELD_LABELS.get(key, key))
		label.custom_minimum_size.x = LABEL_W
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		row.add_child(label)

		var font_dropdown := OptionButton.new()
		font_dropdown.custom_minimum_size.x = FONT_W
		font_dropdown.size_flags_horizontal = Control.SIZE_FILL
		font_dropdown.fit_to_longest_item = false
		font_dropdown.clip_text = true
		font_dropdown.item_selected.connect(_on_field_font_selected.bind(key))
		row.add_child(font_dropdown)

		var size_spin := SpinBox.new()
		size_spin.min_value = 8
		size_spin.max_value = 120
		size_spin.value = float(_current_fields.get(key, {}).get("font_size", DEFAULT_SIZES.get(key, 14)))
		size_spin.custom_minimum_size.x = SPIN_W
		size_spin.size_flags_horizontal = Control.SIZE_FILL
		size_spin.value_changed.connect(_on_field_size_changed.bind(key))
		row.add_child(size_spin)

		_field_rows[key] = {"font_dropdown": font_dropdown, "size_spin": size_spin}

		var current_path: String = str(_current_fields.get(key, {}).get("font_path", ""))
		_rebuild_font_dropdown_inner(font_dropdown, current_path)

func _rebuild_font_dropdown(key: String) -> void:
	if not _field_rows.has(key):
		return
	var dropdown: OptionButton = _field_rows[key]["font_dropdown"]
	var cur_path: String = str(_current_fields.get(key, {}).get("font_path", ""))
	_rebuild_font_dropdown_inner(dropdown, cur_path)

func _rebuild_font_dropdown_inner(dropdown: OptionButton, current_path: String) -> void:
	dropdown.clear()
	dropdown.add_item("系统默认")
	dropdown.set_item_metadata(0, "")
	var selected_index: int = 0
	for i in range(_system_fonts.size()):
		var f = _system_fonts[i]
		if not (f is Dictionary):
			continue
		var f_name: String = str(f.get("name", ""))
		var f_path: String = str(f.get("path", ""))
		if f_name.is_empty() or f_path.is_empty():
			continue
		if not _is_font_allowed(f_name):
			continue
		var display_name: String = f_name
		if display_name.length() > 32:
			display_name = display_name.substr(0, 30) + "…"
		dropdown.add_item(display_name)
		var idx: int = dropdown.item_count - 1
		dropdown.set_item_metadata(idx, f_path)
		if f_path == current_path and current_path != "true" and current_path != "false":
			selected_index = idx
	dropdown.select(selected_index)

func _is_font_allowed(name: String) -> bool:
	if _has_chinese_char(name):
		return true
	for kw in FONT_NAME_KEYWORDS:
		if name.contains(kw):
			return true
	return false

func _has_chinese_char(text: String) -> bool:
	for i in range(text.length()):
		var c: int = text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			return true
	return false

# ──────────────── 编辑回调 ────────────────

func _on_field_font_selected(index: int, key: String) -> void:
	var dropdown: OptionButton = _field_rows[key]["font_dropdown"]
	var meta = dropdown.get_item_metadata(index)
	var chosen: String = "" if meta == null else str(meta)
	if not _current_fields.has(key):
		_current_fields[key] = {}
	_current_fields[key]["font_path"] = chosen
	_mark_dirty()
	if _preview_timer != null:
		_preview_timer.start()

func _on_field_size_changed(value: float, key: String) -> void:
	if not _current_fields.has(key):
		_current_fields[key] = {}
	_current_fields[key]["font_size"] = int(value)
	_mark_dirty()
	if _preview_timer != null:
		_preview_timer.start()

func _mark_dirty() -> void:
	if _current_id == "default":
		return
	_dirty = true
	if _btn_save != null:
		_btn_save.disabled = false
	if _status_label != null:
		_status_label.text = "有未保存的改动"

func _update_buttons_state() -> void:
	var is_default: bool = (_current_id == "default")
	_btn_rename.disabled = is_default
	_btn_delete.disabled = is_default
	_name_field.editable = not is_default
	if _btn_save != null:
		_btn_save.disabled = is_default or not _dirty

# ──────────────── 预览 ────────────────

func _apply_preview_text_for_scope() -> void:
	if _current_scope == SCOPE_MOVIES:
		_prev_top1.text = PREV_MOVIE_TOP1
		_prev_title.text = PREV_MOVIE_TITLE
		_prev_top3.text = PREV_MOVIE_TOP3
		_prev_desc.text = PREV_MOVIE_DESC
		_prev_mid.text = PREV_MOVIE_MID
		_prev_ui.text = PREV_MOVIE_UI
	else:
		_prev_top1.text = PREV_GAME_TOP1
		_prev_title.text = PREV_GAME_TITLE
		_prev_top3.text = PREV_GAME_TOP3
		_prev_desc.text = PREV_GAME_DESC
		_prev_mid.text = PREV_GAME_MID
		_prev_ui.text = PREV_GAME_UI

func _update_preview() -> void:
	if _font_manager == null:
		return
	# 显式映射：字段 → 预览行，不依赖顺序
	var mapping: Dictionary
	if _current_scope == SCOPE_MOVIES:
		mapping = {
			"movie_year":    _prev_top1,
			"movie_title":   _prev_title,
			"movie_meta":    _prev_top3,
			"movie_desc":    _prev_desc,
			"movie_tagline": _prev_mid,
			"ui_default":    _prev_ui,
		}
	else:
		mapping = {
			"game_playtime": _prev_top1,
			"game_title":    _prev_title,
			"game_meta":     _prev_top3,
			"game_desc":     _prev_desc,
			"game_sidebar":  _prev_mid,
			"ui_default":    _prev_ui,
		}
	for key in mapping.keys():
		_apply_preview_style(mapping[key], key)

func _apply_preview_style(label: Label, key: String) -> void:
	if label == null:
		return
	var entry = _current_fields.get(key, {})
	var font_path: String = str(entry.get("font_path", ""))
	var font_size: int = int(entry.get("font_size", DEFAULT_SIZES.get(key, 14)))
	if font_path.is_empty() or font_path == "true" or font_path == "false":
		label.remove_theme_font_override("font")
	else:
		if _font_manager != null and _font_manager.has_method("get_font_for_path"):
			var f: FontFile = _font_manager.get_font_for_path(font_path)
			if f != null:
				label.add_theme_font_override("font", f)
			else:
				label.remove_theme_font_override("font")
	label.add_theme_font_size_override("font_size", font_size)

# ──────────────── 信号输出 ────────────────

func _on_new_pressed() -> void:
	emit_signal("action_requested", "create", {
		"name": "新组别",
		"copy_from": "",
		"scope": _current_scope,
	})

func _on_copy_pressed() -> void:
	if _current_id.is_empty():
		return
	emit_signal("action_requested", "create", {
		"name": "副本",
		"copy_from": _current_id,
		"scope": _current_scope,
	})

func _on_rename_pressed() -> void:
	if _current_id == "default" or _name_field.text.strip_edges().is_empty():
		return
	emit_signal("action_requested", "rename", {
		"id": _current_id,
		"name": _name_field.text.strip_edges(),
		"scope": _current_scope,
	})

func _on_delete_pressed() -> void:
	if _current_id == "default":
		return
	emit_signal("action_requested", "delete", {
		"id": _current_id,
		"scope": _current_scope,
	})

func _on_save_pressed() -> void:
	if _current_id == "default":
		return
	emit_signal("action_requested", "save", {
		"id": _current_id,
		"name": _name_field.text.strip_edges(),
		"scope": _current_scope,
		"fields": _current_fields,
	})

func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text