extends Window
class_name G3LibraryScanDialog

signal scan_requested(tab_id: String)
signal import_requested(tab_id: String, items: Array)
signal closed()

const TEXT_MENU_LOCALIZER: Script = preload("res://scripts/text_context_menu_localizer.gd")

const STATUS_W: float = 64.0
const PLATFORM_W: float = 56.0
const SIZE_W: float = 80.0
const TAB_H: float = 30.0

const COLOR_NEW: Color = Color(0.52, 0.86, 0.60)
const COLOR_EXISTING: Color = Color(0.55, 0.58, 0.62)

const TAB_EMULATOR: String = "emulator"
const TAB_STEAM: String = "steam"
const TAB_GOG: String = "gog"
const TAB_EPIC: String = "epic"
const TAB_UPLAY: String = "uplay"
const TAB_ROCKSTAR: String = "rockstar"
const TAB_PSN: String = "psn"

# 显示顺序
const TAB_ORDER: Array = [TAB_EMULATOR, TAB_STEAM, TAB_GOG, TAB_EPIC, TAB_UPLAY, TAB_ROCKSTAR, TAB_PSN]
const TAB_LABELS: Dictionary = {
	TAB_EMULATOR: "模拟器",
	TAB_STEAM: "Steam",
	TAB_GOG: "GOG",
	TAB_EPIC: "Epic",
	TAB_UPLAY: "Uplay",
	TAB_ROCKSTAR: "Rockstar",
	TAB_PSN: "PSN",
}

# 每个 tab 的标题取值字段（依次尝试）
const TAB_TITLE_KEYS: Dictionary = {
	TAB_EMULATOR: ["suggested_title", "title", "name"],
	TAB_STEAM: ["name", "title"],
	TAB_GOG: ["title", "name"],
	TAB_EPIC: ["title", "name"],
	TAB_UPLAY: ["title", "name"],
	TAB_ROCKSTAR: ["title", "name"],
	TAB_PSN: ["title", "name"],	
}

# tooltip 取值字段
const TAB_TIP_KEYS: Dictionary = {
	TAB_EMULATOR: ["rom_path", "install_dir"],
	TAB_STEAM: ["install_dir"],
	TAB_GOG: ["install_dir"],
	TAB_EPIC: ["install_dir"],
	TAB_UPLAY: ["install_dir"],
	TAB_ROCKSTAR: ["install_dir"],
	TAB_PSN: ["install_dir"],	
}

var _active_tab: String = TAB_EMULATOR
# tab_id -> Array，每个 tab 独立缓存
var _tab_items: Dictionary = {}
# tab_id -> Button
var _tab_buttons: Dictionary = {}
# tab_id -> bool，标记「是否已扫过」
var _tab_import_flags: Dictionary = {}
# tab_id -> Control（放行列表的容器）
var _tab_lists: Dictionary = {}
# tab_id -> Label（空列表提示）
var _tab_empty: Dictionary = {}

# 当前 tab 的行控件
var _checks: Array = []
var _title_labels: Array = []

var _tabs_row: HBoxContainer
var _summary_label: Label
var _list_area: Control
var _select_all_btn: Button
var _select_none_btn: Button
var _cancel_btn: Button
var _import_btn: Button

func _ready() -> void:
	title = "扫描游戏库"
	size = Vector2i(760, 640)
	min_size = Vector2i(620, 480)
	transient = true
	exclusive = true
	close_requested.connect(_on_close_requested)
	_build_ui()
	TEXT_MENU_LOCALIZER.localize_tree(self)
	call_deferred("_localize_context_menus")
	hide()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# ---- tab 按钮行 ----
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 6)
	root.add_child(_tabs_row)

	for tab_id in TAB_ORDER:
		var btn := Button.new()
		btn.text = str(TAB_LABELS.get(tab_id, tab_id))
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(96.0, TAB_H)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_tab_pressed.bind(str(tab_id)))
		_tabs_row.add_child(btn)
		_tab_buttons[str(tab_id)] = btn
		_tab_import_flags[str(tab_id)] = false

	# ---- 摘要 + 工具按钮 ----
	_summary_label = Label.new()
	_summary_label.text = "尚未扫描"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 14)
	root.add_child(_summary_label)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	root.add_child(tools)

	_select_all_btn = Button.new()
	_select_all_btn.text = "全选"
	_select_all_btn.custom_minimum_size = Vector2(80.0, 30.0)
	_select_all_btn.pressed.connect(_on_select_all)
	tools.add_child(_select_all_btn)

	_select_none_btn = Button.new()
	_select_none_btn.text = "全不选"
	_select_none_btn.custom_minimum_size = Vector2(80.0, 30.0)
	_select_none_btn.pressed.connect(_on_select_none)
	tools.add_child(_select_none_btn)

	# ---- 列表区（每个 tab 一个 ScrollContainer，互斥显示）----
	_list_area = Control.new()
	_list_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_list_area)

	for tab_id in TAB_ORDER:
		var key := str(tab_id)

		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.visible = false
		_list_area.add_child(scroll)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		scroll.add_child(vbox)
		_tab_lists[key] = vbox

		var empty := Label.new()
		empty.text = "（这个平台没有扫描到可导入的游戏）"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", COLOR_EXISTING)
		empty.visible = false
		vbox.add_child(empty)
		_tab_empty[key] = empty

	# ---- 底部按钮 ----
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(buttons)

	_cancel_btn = Button.new()
	_cancel_btn.text = "取消"
	_cancel_btn.pressed.connect(hide)
	buttons.add_child(_cancel_btn)

	_import_btn = Button.new()
	_import_btn.text = "导入选中"
	_import_btn.pressed.connect(_on_import_pressed)
	buttons.add_child(_import_btn)

# ---------------------------------------------------------------------------
# 对外

func show_dialog() -> void:
	# 每次打开都当全新的：清空所有 tab 缓存
	_clear_all_caches()
	_active_tab = TAB_EMULATOR
	_apply_tab_visibility()
	_summary_label.text = "正在扫描…"
	_import_btn.text = "导入选中"
	_set_tools_enabled(false)

	# 自适应父窗口尺寸
	var parent_win: Window = null
	if get_parent() != null:
		parent_win = get_parent().get_window()
	if parent_win != null:
		var target_w: int = mini(760, maxi(620, parent_win.size.x - 80))
		var target_h: int = mini(640, maxi(480, parent_win.size.y - 80))
		size = Vector2i(target_w, target_h)

	if not visible:
		popup_centered()

	# 默认选中「模拟器」tab 并立即扫描
	scan_requested.emit(_active_tab)

func show_scan_results(tab_id: String, items: Array) -> void:
	var key := str(tab_id)
	_tab_items[key] = items
	_tab_import_flags[key] = true
	# 保证「容器可见性」始终和 _active_tab 一致，不依赖 show_dialog 先跑过
	_apply_tab_visibility()
	if key == _active_tab:
		_rebuild_active_list()
	# 已经关窗了就不要重新弹出来
	if not visible:
		return

func set_import_progress(tab_id: String, done: int, total: int) -> void:
	if str(tab_id) != _active_tab:
		return
	_import_btn.disabled = true
	_import_btn.text = "导入中 %d/%d" % [done, total]
	_summary_label.text = "导入中 %d/%d" % [done, total]

func set_import_done(tab_id: String, added: int, skipped: int, errors: int) -> void:
	if str(tab_id) != _active_tab:
		return
	_import_btn.text = "导入选中"
	_set_tools_enabled(true)
	var total_new: int = _count_new(_active_tab)
	var parts: Array = [
		"共扫描到 %d 个游戏" % _get_items(_active_tab).size(),
		"新增 %d" % total_new,
		"本次导入 %d" % added,
	]
	if skipped > 0:
		parts.append("跳过 %d" % skipped)
	if errors > 0:
		parts.append("失败 %d" % errors)
	_summary_label.text = " · ".join(parts)

func get_checked_items() -> Array:
	var items: Array = _get_items(_active_tab)
	var result: Array = []
	for i in range(items.size()):
		if i >= _checks.size():
			break
		var box: CheckBox = _checks[i]
		if box != null and is_instance_valid(box) and box.button_pressed:
			result.append(items[i])
	return result

func get_active_tab() -> String:
	return _active_tab

func has_scanned(tab_id: String) -> bool:
	return bool(_tab_import_flags.get(str(tab_id), false))

func begin_scan(tab_id: String) -> void:
	"""标记某个 tab 正在扫描（切到它时不会重复发命令，也不显示旧缓存）。"""
	var key := str(tab_id)
	_tab_items.erase(key)
	_tab_import_flags[key] = true
	_apply_tab_visibility()
	if key == _active_tab:
		_rebuild_active_list()

func show_scan_error(tab_id: String, message: String) -> void:
	var key := str(tab_id)
	_tab_items[key] = []
	_tab_import_flags[key] = true
	if key == _active_tab and visible:
		_summary_label.text = "扫描失败：%s" % message
		_import_btn.text = "导入选中"
		_set_tools_enabled(false)

# ---------------------------------------------------------------------------
# 内部

func _get_items(tab_id: String) -> Array:
	var raw: Variant = _tab_items.get(str(tab_id), [])
	return raw if raw is Array else []

func _count_new(tab_id: String) -> int:
	var count: int = 0
	for item in _get_items(tab_id):
		if item is Dictionary and not bool((item as Dictionary).get("already_exists", false)):
			count += 1
	return count

func _clear_all_caches() -> void:
	_tab_items.clear()
	for tab_id in TAB_ORDER:
		_tab_import_flags[str(tab_id)] = false
	_checks.clear()
	_title_labels.clear()
	for tab_id in TAB_ORDER:
		var vbox: Variant = _tab_lists.get(str(tab_id))
		if vbox is Node:
			_clear_container(vbox as Node)
	_apply_tab_visibility()

func _clear_container(container: Node) -> void:
	# 只删行控件，保留「空列表提示」Label
	for child in container.get_children():
		if child is Label:
			continue
		container.remove_child(child)
		child.queue_free()

func _apply_tab_visibility() -> void:
	# 注意：这里必须用 _tab_lists 把「每个 tab」映射到「它自己的容器」，
	# 不能在内层遍历 _list_area 的所有子节点 —— 那会在每一轮循环里
	# 把所有容器都设成同一个值，最后一轮（TAB_ORDER 的最后一个 tab）
	# 会覆盖前面所有结果，导致要么全隐藏、要么全显示（互相叠着串数据）。
	for tab_id in TAB_ORDER:
		var key := str(tab_id)
		var is_active: bool = key == _active_tab

		var btn: Variant = _tab_buttons.get(key)
		if btn is Button:
			(btn as Button).disabled = is_active

		var vbox: Variant = _tab_lists.get(key)
		if vbox is Node:
			var scroll: Node = (vbox as Node).get_parent()
			if scroll is CanvasItem:
				(scroll as CanvasItem).visible = is_active

func _on_close_requested() -> void:
	_clear_all_caches()
	_active_tab = TAB_EMULATOR
	_summary_label.text = "尚未扫描"
	_import_btn.text = "导入选中"
	_set_tools_enabled(false)
	hide()
	# 通知 main 一起清掉它那份扫描结果缓存
	closed.emit()

func _on_tab_pressed(tab_id: String) -> void:
	if tab_id == _active_tab:
		return
	_active_tab = tab_id
	_apply_tab_visibility()
	if not has_scanned(tab_id):
		# 没扫过 → 发扫描命令
		_summary_label.text = "正在扫描…"
		_set_tools_enabled(false)
		scan_requested.emit(tab_id)
	else:
		# 已扫过 → 直接显示缓存
		_rebuild_active_list()

func _set_tools_enabled(enabled: bool) -> void:
	_select_all_btn.disabled = not enabled
	_select_none_btn.disabled = not enabled
	_import_btn.disabled = not enabled

func _rebuild_active_list() -> void:
	_checks.clear()
	_title_labels.clear()

	var items: Array = _get_items(_active_tab)
	var vbox: Variant = _tab_lists.get(_active_tab)
	if not (vbox is Node):
		return
	var container: Node = vbox as Node
	_clear_container(container)
	_checks.resize(items.size())
	_title_labels.resize(items.size())

	var empty: Variant = _tab_empty.get(_active_tab)
	if empty is Label:
		(empty as Label).visible = items.is_empty()

	for i in range(items.size()):
		var raw: Variant = items[i]
		if not (raw is Dictionary):
			continue
		container.add_child(_make_result_row(i, raw as Dictionary))

	# 摘要
	var total: int = items.size()
	var new_count: int = _count_new(_active_tab)
	_summary_label.text = "共扫描到 %d 个游戏（新增 %d / 已存在 %d）" % [
		total, new_count, total - new_count
	]
	_import_btn.text = "导入选中"
	_set_tools_enabled(true)

func _pick_field(item: Dictionary, keys: Array, fallback: String = "") -> String:
	for key in keys:
		var value: String = str(item.get(str(key), "")).strip_edges()
		if not value.is_empty():
			return value
	return fallback

func _make_result_row(index: int, item: Dictionary) -> HBoxContainer:
	var exists: bool = bool(item.get("already_exists", false))
	var is_steam: bool = _active_tab == TAB_STEAM

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_NONE
	# 新增项默认勾选；已存在项默认不勾选（仍可手动勾，但导入时会跳过）
	box.button_pressed = not exists
	row.add_child(box)
	_checks[index] = box

	var info_row := HBoxContainer.new()
	info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_theme_constant_override("separation", 8)
	row.add_child(info_row)

	var title := Label.new()
	title.text = _pick_field(item, TAB_TITLE_KEYS.get(_active_tab, ["title"]))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 13)
	if exists:
		title.add_theme_color_override("font_color", COLOR_EXISTING)
	info_row.add_child(title)
	_title_labels[index] = title

	# 只有 Steam tab 显示安装大小
	if is_steam:
		var size_gb: float = float(item.get("install_size_gb", 0.0))
		var size_label := Label.new()
		size_label.text = ("%.1f GB" % size_gb) if size_gb > 0.0 else "—"
		size_label.custom_minimum_size = Vector2(SIZE_W, 0.0)
		size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		size_label.add_theme_font_size_override("font_size", 12)
		size_label.add_theme_color_override("font_color", COLOR_EXISTING)
		info_row.add_child(size_label)

	# 模拟器 tab 显示平台标签
	if _active_tab == TAB_EMULATOR:
		var platform_text: String = str(item.get("platform_tag", "")).strip_edges()
		var platform := Label.new()
		platform.text = platform_text if not platform_text.is_empty() else "—"
		platform.custom_minimum_size = Vector2(PLATFORM_W, 0.0)
		platform.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		platform.add_theme_font_size_override("font_size", 12)
		platform.add_theme_color_override("font_color", COLOR_EXISTING)
		info_row.add_child(platform)

	var status := Label.new()
	status.text = "已存在" if exists else "新增"
	status.custom_minimum_size = Vector2(STATUS_W, 0.0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", COLOR_EXISTING if exists else COLOR_NEW)
	info_row.add_child(status)
	return row

func _on_select_all() -> void:
	# 只勾新增项，不勾已存在
	var items: Array = _get_items(_active_tab)
	for i in range(items.size()):
		if i >= _checks.size():
			break
		var box: CheckBox = _checks[i]
		if box == null or not is_instance_valid(box):
			continue
		var raw: Variant = items[i]
		var exists: bool = false
		if raw is Dictionary:
			exists = bool((raw as Dictionary).get("already_exists", false))
		box.button_pressed = not exists

func _on_select_none() -> void:
	for box in _checks:
		if box != null and is_instance_valid(box):
			box.button_pressed = false

func _on_import_pressed() -> void:
	var checked: Array = get_checked_items()
	if checked.is_empty():
		_summary_label.text = "请先勾选要导入的游戏"
		return
	_import_btn.disabled = true
	_import_btn.text = "导入中…"
	import_requested.emit(_active_tab, checked)

func _localize_context_menus() -> void:
	TEXT_MENU_LOCALIZER.localize_tree(self)
