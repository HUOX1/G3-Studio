extends Window
class_name G3GameScraperDialog

signal search_requested(query: String)
signal assets_requested(sgdb_id: int, asset_type: String, batch_id: String)
signal asset_info_requested(url: String)
signal apply_requested(item_id: String, sgdb_id: int, asset_type: String, url: String, operation_id: String)

const ASSET_TYPES: Array[String] = ["grid", "hero", "logo", "icon"]
const ASSET_LABELS: Dictionary = {
	"grid": "封面（竖版）",
	"hero": "壁纸（横版）",
	"logo": "LOGO（透明底）",
	"icon": "图标（侧边栏用）",
}
const THUMB_SIZE: Vector2 = Vector2(198.0, 140.0)

var _item_id: String = ""
var _game_title: String = ""

var _query_field: LineEdit
var _status_label: Label
var _results_list: VBoxContainer
var _apply_button: Button
var _sections_root: VBoxContainer
var _progress_root: VBoxContainer
var _progress_stage: Label
var _progress_bar: ProgressBar
var _progress_detail: Label
var _image_info_label: Label
var _cancel_button: Button
var _spinner_elapsed: float = 0.0
var _spinner_frame: int = 0
var _progress_caption: String = ""
var _assets_batch_id: String = ""
var _asset_responses: Dictionary = {}
var _thumb_totals: Dictionary = {}
var _thumb_progress: Dictionary = {}
var _early_thumbs: Dictionary = {}
var _apply_queue: Array[Dictionary] = []
var _apply_index: int = 0
var _apply_operation_id: String = ""
var _apply_active: bool = false

var _search_results: Array = []
var _selected_sgdb_id: int = 0
var _selected_result_btn: Button = null
var _tab_buttons: Dictionary = {}
var _active_tab: String = "grid"

# asset_type -> { "row": HBoxContainer, "selected_url": String, "loaded": bool }
var _sections: Dictionary = {}
# asset_type -> Dictionary(卡片字典，url -> Button)
var _thumb_cards: Dictionary = {}

func _ready() -> void:
	title = "从 SteamGridDB 获取素材"
	size = Vector2i(780, 760)
	min_size = Vector2i(680, 620)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
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

	var heading := Label.new()
	heading.text = "从 SteamGridDB 获取素材"
	heading.add_theme_font_size_override("font_size", 18)
	root.add_child(heading)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	root.add_child(search_row)

	_query_field = LineEdit.new()
	_query_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query_field.placeholder_text = "英文名，例如 Rain World"
	_query_field.text_submitted.connect(func(_t): _on_search_pressed())
	search_row.add_child(_query_field)

	var search_btn := Button.new()
	search_btn.text = "搜索"
	search_btn.pressed.connect(_on_search_pressed)
	search_row.add_child(search_btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.62, 0.78, 0.80))
	root.add_child(_status_label)

	# Embedded progress: indeterminate for network/search/encoding, real counts
	# and bytes only when the backend provides measurable progress.
	_progress_root = VBoxContainer.new()
	_progress_root.add_theme_constant_override("separation", 3)
	_progress_root.visible = false
	root.add_child(_progress_root)
	_progress_stage = Label.new()
	_progress_stage.add_theme_font_size_override("font_size", 12)
	_progress_stage.add_theme_color_override("font_color", Color(0.70, 0.88, 1.0))
	_progress_root.add_child(_progress_stage)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	_progress_bar.show_percentage = false
	_progress_bar.indeterminate = true
	_progress_root.add_child(_progress_bar)
	_progress_detail = Label.new()
	_progress_detail.add_theme_font_size_override("font_size", 11)
	_progress_detail.add_theme_color_override("font_color", Color(0.57, 0.69, 0.76))
	_progress_root.add_child(_progress_detail)
	_image_info_label = Label.new()
	_image_info_label.add_theme_font_size_override("font_size", 11)
	_image_info_label.add_theme_color_override("font_color", Color(0.65, 0.78, 0.85))
	root.add_child(_image_info_label)

	var results_scroll := ScrollContainer.new()
	results_scroll.custom_minimum_size = Vector2(0, 150)
	results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	results_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(results_scroll)

	_results_list = VBoxContainer.new()
	_results_list.add_theme_constant_override("separation", 2)
	_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_scroll.add_child(_results_list)

	# Tab 栏
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	root.add_child(tab_bar)
	for t in ASSET_TYPES:
		var tab_btn := Button.new()
		tab_btn.text = str(ASSET_LABELS.get(t, t))
		tab_btn.focus_mode = Control.FOCUS_NONE
		tab_btn.toggle_mode = true
		tab_btn.custom_minimum_size = Vector2(120.0, 32.0)
		tab_btn.pressed.connect(_on_tab_pressed.bind(t))
		tab_bar.add_child(tab_btn)
		_tab_buttons[t] = tab_btn

	# 素材区：每个 section 一个 ScrollContainer，只显示当前 tab
	_sections_root = VBoxContainer.new()
	_sections_root.add_theme_constant_override("separation", 8)
	_sections_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_sections_root)

	for t in ASSET_TYPES:
		_build_section(t)

	_on_tab_pressed("grid")

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(buttons)

	_cancel_button = Button.new()
	_cancel_button.text = "取消"
	_cancel_button.pressed.connect(hide)
	buttons.add_child(_cancel_button)

	_apply_button = Button.new()
	_apply_button.text = "应用选中"
	_apply_button.disabled = true
	_apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_button)

func _build_section(asset_type: String) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.visible = false
	_sections_root.add_child(section)

	var cell: Vector2 = THUMB_SIZE
	if asset_type == "icon":
		cell = Vector2(172.0, 172.0)
	elif asset_type == "hero":
		cell = Vector2(320.0, 172.0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, cell.y + 40.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	section.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)

	_sections[asset_type] = {
		"row": row,
		"selected_url": "",
		"cell": cell,
		"section": section,
	}
	_thumb_cards[asset_type] = {}

func _on_tab_pressed(asset_type: String) -> void:
	_active_tab = asset_type
	for t in _sections.keys():
		var sec: Dictionary = _sections[t]
		var section: VBoxContainer = sec.get("section", null)
		if section != null:
			section.visible = (t == asset_type)
	for t in _tab_buttons.keys():
		var btn: Button = _tab_buttons[t]
		btn.button_pressed = (t == asset_type)

# ---------- 进度反馈 ----------

func _process(delta: float) -> void:
	if not _progress_root.visible:
		return
	_spinner_elapsed += delta
	if _spinner_elapsed < 0.16:
		return
	_spinner_elapsed = 0.0
	_spinner_frame = (_spinner_frame + 1) % 4
	var frames: Array[String] = ["◐", "◓", "◑", "◒"]
	_progress_stage.text = "%s  %s" % [frames[_spinner_frame], _progress_caption]

func _show_progress(caption: String, detail: String = "", value: float = -1.0) -> void:
	_progress_caption = caption
	_progress_root.visible = true
	_progress_stage.text = "◐  " + caption
	_progress_detail.text = detail
	_progress_bar.indeterminate = value < 0.0
	if value >= 0.0:
		_progress_bar.value = clampf(value, 0.0, 100.0)

func _hide_progress() -> void:
	_progress_root.visible = false
	_progress_caption = ""

func _format_bytes(count: int) -> String:
	if count <= 0:
		return "未知"
	if count >= 1024 * 1024:
		return "%.2f MB" % (float(count) / (1024.0 * 1024.0))
	return "%.1f KB" % (float(count) / 1024.0)

func _update_asset_progress() -> void:
	if _apply_active:
		return
	var completed_lists: int = _asset_responses.size()
	if completed_lists < ASSET_TYPES.size():
		_show_progress("搜索素材 · 获取列表", "%d / %d 类素材已返回" % [completed_lists, ASSET_TYPES.size()], float(completed_lists) * 100.0 / float(ASSET_TYPES.size()))
		return
	var total: int = 0
	var done: int = 0
	for t in ASSET_TYPES:
		total += int(_thumb_totals.get(t, 0))
		done += mini(int(_thumb_progress.get(t, 0)), int(_thumb_totals.get(t, 0)))
	if total > 0 and done < total:
		_show_progress("下载缩略图", "%d / %d 张已处理" % [done, total], float(done) * 100.0 / float(total))
	else:
		_hide_progress()
		_status_label.text = "素材已加载，点击选中后应用"

func show_thumb_progress(payload: Dictionary) -> void:
	if not visible or _apply_active:
		return
	if str(payload.get("batch_id", "")) != _assets_batch_id:
		return
	if int(payload.get("sgdb_id", 0)) != _selected_sgdb_id:
		return
	var t: String = str(payload.get("asset_type", ""))
	if not _sections.has(t):
		return
	_thumb_progress[t] = maxi(int(_thumb_progress.get(t, 0)), int(payload.get("done", 0)))
	var url: String = str(payload.get("url", ""))
	var path: String = str(payload.get("thumb_local", ""))
	if not path.is_empty():
		_early_thumbs["%s:%s" % [t, url]] = path
		_update_thumb_preview(t, url, path)
	_update_asset_progress()

func _update_thumb_preview(t: String, url: String, path: String) -> void:
	var cards: Dictionary = _thumb_cards.get(t, {})
	var btn: Button = cards.get(url, null)
	if btn == null or not is_instance_valid(btn) or bool(btn.get_meta("preview_loaded", false)):
		return
	if not FileAccess.file_exists(path):
		return
	var img := Image.new()
	if img.load(path) != OK:
		return
	var placeholder: Node = btn.get_node_or_null("G3Placeholder")
	if placeholder != null:
		placeholder.queue_free()
	var tex_rect := TextureRect.new()
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture = ImageTexture.create_from_image(img)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tex_rect)
	btn.move_child(tex_rect, 0)
	btn.set_meta("preview_loaded", true)

func show_asset_info(data: Dictionary) -> void:
	var url: String = str(data.get("url", ""))
	if not visible or _active_tab != "hero":
		return
	if str(_sections["hero"].get("selected_url", "")) != url:
		return
	_image_info_label.text = "选中 Hero · 原图体积：%s" % _format_bytes(int(data.get("file_size", 0)))

func show_apply_progress(payload: Dictionary) -> void:
	if not visible or not _apply_active:
		return
	if str(payload.get("operation_id", "")) != _apply_operation_id:
		return
	if _apply_index >= _apply_queue.size():
		return
	var current: Dictionary = _apply_queue[_apply_index]
	if str(payload.get("asset_type", "")) != str(current.get("type", "")):
		return
	var label: String = str(ASSET_LABELS.get(str(current.get("type", "")), "素材"))
	var step: String = "%d / %d · %s" % [_apply_index + 1, _apply_queue.size(), label]
	match str(payload.get("phase", "")):
		"download":
			var downloaded: int = int(payload.get("downloaded", 0))
			var total: int = int(payload.get("total", 0))
			var download_detail: String = "%s / %s" % [_format_bytes(downloaded), _format_bytes(total)] if total > 0 else "%s · 总量未知" % _format_bytes(downloaded)
			_show_progress("下载原图 · " + step, download_detail, float(downloaded) * 100.0 / float(total) if total > 0 else -1.0)
		"optimize":
			var stage_name: String = str(payload.get("stage", ""))
			var original_label: String = _format_bytes(int(payload.get("original_bytes", 0)))
			match stage_name:
				"decode":
					var done: int = int(payload.get("done", 0))
					var total: int = maxi(int(payload.get("total", 0)), 1)
					_show_progress("优化动态封面 · " + step, "解析画面 %d / %d · 原图 %s" % [done, total, original_label], float(done) / float(total) * 70.0)
				"encode":
					_show_progress("优化动态封面 · " + step, "正在重新编码 · 原图 %s（此阶段无法精确计算百分比）" % original_label)
				"verify":
					_show_progress("优化动态封面 · " + step, "正在校验动画帧与时长")
				"skipped_large_animation":
					_show_progress("保留动态封面原图 · " + step, "动画规模过大，跳过压缩以保护内存")
				_:
					_show_progress("优化素材 · " + step, "原图 %s · 处理中" % original_label)
		"save":
			var original: int = int(payload.get("original_bytes", 0))
			var final_size: int = int(payload.get("final_bytes", 0))
			var save_detail: String = "%s → %s" % [_format_bytes(original), _format_bytes(final_size)] if bool(payload.get("optimized", false)) else "保留原图 · %s" % _format_bytes(original)
			_show_progress("应用素材 · " + step, save_detail)
			if str(current.get("type", "")) == "hero":
				_image_info_label.text = "Hero 文件：" + save_detail

func on_apply_result(asset_type: String, operation_id: String, ok: bool, data: Variant) -> bool:
	if operation_id != _apply_operation_id:
		return false
	if not _apply_active or _apply_index >= _apply_queue.size():
		return false
	if str(_apply_queue[_apply_index].get("type", "")) != asset_type:
		return false
	if not ok:
		_apply_active = false
		_apply_button.text = "重试应用"
		_apply_button.disabled = false
		_cancel_button.disabled = false
		_show_progress("应用失败", "素材未全部应用，请检查错误后重试", 0.0)
		return false
	_apply_index += 1
	if _apply_index < _apply_queue.size():
		_emit_next_apply()
		return false
	_apply_active = false
	_apply_button.text = "应用选中"
	_cancel_button.disabled = false
	var summary: String = "全部 %d 项素材已保存" % _apply_queue.size()
	if data is Dictionary and bool((data as Dictionary).get("optimized", false)):
		summary += " · Hero 已优化"
	_show_progress("应用完成", summary, 100.0)
	return true

func _emit_next_apply() -> void:
	var current: Dictionary = _apply_queue[_apply_index]
	_show_progress("准备下载 · %d / %d" % [_apply_index + 1, _apply_queue.size()])
	apply_requested.emit(_item_id, _selected_sgdb_id, str(current["type"]), str(current["url"]), _apply_operation_id)

func is_apply_active() -> bool:
	return _apply_active

# ---------- 搜索 ----------

func show_for(item_id: String, game_title: String) -> void:
	_item_id = item_id
	_game_title = game_title
	_query_field.text = game_title
	_clear_results()
	_clear_all_sections()
	_assets_batch_id = ""
	_apply_active = false
	_apply_queue.clear()
	_apply_button.text = "应用选中"
	_cancel_button.disabled = false
	_image_info_label.text = ""
	_hide_progress()
	_status_label.text = "点「搜索」开始"
	_apply_button.disabled = true
	popup_centered_clamped(size, 0.85)

func _on_search_pressed() -> void:
	var q: String = _query_field.text.strip_edges()
	if q.is_empty():
		_status_label.text = "请输入搜索词"
		return
	_clear_results()
	_clear_all_sections()
	_assets_batch_id = ""
	_selected_sgdb_id = 0
	_image_info_label.text = ""
	_show_progress("搜索游戏", "正在连接 SteamGridDB…")
	_apply_button.disabled = true
	_status_label.text = "搜索中…"
	search_requested.emit(q)

func show_search_results(results: Array) -> void:
	_search_results = results
	_clear_results()
	if results.is_empty():
		_hide_progress()
		_status_label.text = "没找到。试试输入英文名（如 Silent Hill）"
		return
	_status_label.text = "找到 %d 个结果，如需换游戏请点其它条目" % results.size()
	var first_btn: Button = null
	for raw in results:
		if raw is Dictionary:
			var btn := _make_result_row(raw as Dictionary)
			_results_list.add_child(btn)
			if first_btn == null:
				first_btn = btn
	# 自动选中第一个结果：省一步点击，直接进素材列表
	if first_btn != null:
		var sid: int = int(first_btn.get_meta("sgdb_id"))
		_on_result_clicked(sid, first_btn)

func _clear_results() -> void:
	for c in _results_list.get_children():
		c.queue_free()
	_selected_result_btn = null

func _make_result_row(hit: Dictionary) -> Button:
	var id: int = int(hit.get("id", 0))
	var name: String = str(hit.get("name", ""))
	var types: Array = hit.get("types", [])
	var btn := Button.new()
	if types.is_empty():
		btn.text = name
	else:
		btn.text = "%s  [%s]" % [name, ",".join(types)]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 28)
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("sgdb_id", id)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_result_clicked.bind(id, btn))
	return btn

func _on_result_clicked(sgdb_id: int, btn: Button) -> void:
	if _selected_result_btn != null and is_instance_valid(_selected_result_btn):
		_selected_result_btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_selected_result_btn = btn
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_selected_sgdb_id = sgdb_id
	_clear_all_sections()
	_assets_batch_id = "%d:%d" % [sgdb_id, Time.get_ticks_usec()]
	_asset_responses.clear()
	_thumb_totals.clear()
	_thumb_progress.clear()
	_early_thumbs.clear()
	_image_info_label.text = ""
	_status_label.text = "加载素材中…"
	_update_asset_progress()
	for t in ASSET_TYPES:
		assets_requested.emit(sgdb_id, t, _assets_batch_id)

# ---------- 素材 ----------

func _clear_all_sections() -> void:
	for t in _sections.keys():
		var sec: Dictionary = _sections[t]
		var row: HBoxContainer = sec["row"]
		for c in row.get_children():
			c.queue_free()
		sec["selected_url"] = ""
		_thumb_cards[t] = {}
	_apply_button.disabled = true

func show_assets(asset_type: String, items: Array, batch_id: String) -> void:
	if not visible or batch_id != _assets_batch_id or _apply_active:
		return
	if not _sections.has(asset_type):
		return
	var sec: Dictionary = _sections[asset_type]
	var row: HBoxContainer = sec["row"]
	for c in row.get_children():
		c.queue_free()
	_thumb_cards[asset_type] = {}
	var missing: int = 0
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var thumb_local: String = str(item.get("thumb_local", ""))
		var url: String = str(item.get("url", ""))
		if url.is_empty():
			continue
		var early_path: String = str(_early_thumbs.get("%s:%s" % [asset_type, url], ""))
		if thumb_local.is_empty() and not early_path.is_empty():
			thumb_local = early_path
		if str(item.get("thumb_local", "")).is_empty():
			missing += 1
		var card := _make_thumb_card(asset_type, url, thumb_local, item)
		row.add_child(card)
		var cards: Dictionary = _thumb_cards[asset_type]
		cards[url] = card
	_asset_responses[asset_type] = true
	_thumb_totals[asset_type] = missing
	_update_asset_progress()

func _make_thumb_card(asset_type: String, url: String, thumb_local: String, item: Dictionary) -> Button:
	var btn := Button.new()
	var cell: Vector2 = THUMB_SIZE
	if _sections.has(asset_type):
		cell = _sections[asset_type].get("cell", THUMB_SIZE)
	btn.custom_minimum_size = cell
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta("asset_url", url)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	bg.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("focus", bg)

	var thumb_loaded: bool = false
	if not thumb_local.is_empty() and FileAccess.file_exists(thumb_local):
		var img := Image.new()
		if img.load(thumb_local) == OK:
			var tex_rect := TextureRect.new()
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.texture = ImageTexture.create_from_image(img)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tex_rect)
			thumb_loaded = true
	btn.set_meta("preview_loaded", thumb_loaded)
	if not thumb_loaded:
		# 没缩略图:显示占位文字,让用户知道这是可点的按钮
		var ph := Label.new()
		ph.name = "G3Placeholder"
		ph.text = "加载中…"
		ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph.add_theme_font_size_override("font_size", 11)
		ph.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58))
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(ph)

	var w: int = int(item.get("width", 0))
	var h: int = int(item.get("height", 0))
	var size_text: String = "%dx%d" % [w, h] if w > 0 else "—"
	var info := Label.new()
	var file_size: int = int(item.get("file_size", 0))
	info.text = "%s · %s" % [size_text, _format_bytes(file_size)] if file_size > 0 else size_text
	info.anchor_left = 0.0
	info.anchor_right = 1.0
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_top = -18.0
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(info)

	# 动图标记：只在 is_animated 为 true 时加，放右上角
	if bool(item.get("is_animated", false)):
		var badge_wrap := PanelContainer.new()
		badge_wrap.anchor_left = 1.0
		badge_wrap.anchor_right = 1.0
		badge_wrap.anchor_top = 0.0
		badge_wrap.anchor_bottom = 0.0
		badge_wrap.offset_left = -72.0
		badge_wrap.offset_right = -6.0
		badge_wrap.offset_top = 6.0
		badge_wrap.offset_bottom = 28.0
		badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wrap_style := StyleBoxFlat.new()
		wrap_style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
		wrap_style.set_corner_radius_all(3)
		wrap_style.content_margin_left = 4.0
		wrap_style.content_margin_right = 4.0
		wrap_style.content_margin_top = 1.0
		wrap_style.content_margin_bottom = 1.0
		badge_wrap.add_theme_stylebox_override("panel", wrap_style)
		var badge_label := Label.new()
		badge_label.text = "▶ 动图"
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", 11)
		badge_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_wrap.add_child(badge_label)
		btn.add_child(badge_wrap)

	# 覆盖层：画在最上层，边框/高亮不会被缩略图遮住
	var overlay := Panel.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0, 0, 0, 0)
	ov_style.set_corner_radius_all(4)
	overlay.add_theme_stylebox_override("panel", ov_style)
	btn.add_child(overlay)
	btn.set_meta("overlay", overlay)
	btn.set_meta("selected", false)

	btn.mouse_entered.connect(_on_thumb_hover.bind(btn))
	btn.mouse_exited.connect(_on_thumb_unhover.bind(btn))

	btn.pressed.connect(_on_thumb_clicked.bind(asset_type, url))
	return btn

func _on_thumb_hover(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	if bool(btn.get_meta("selected", false)):
		return
	if not btn.has_meta("overlay"):
		return
	var ov: Panel = btn.get_meta("overlay")
	if ov == null:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.62, 0.86, 1.0, 0.20)
	s.border_color = Color(0.62, 0.86, 1.0, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	ov.add_theme_stylebox_override("panel", s)

func _on_thumb_unhover(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	if bool(btn.get_meta("selected", false)):
		return
	if not btn.has_meta("overlay"):
		return
	var ov: Panel = btn.get_meta("overlay")
	if ov == null:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_corner_radius_all(4)
	ov.add_theme_stylebox_override("panel", s)

func _on_thumb_clicked(asset_type: String, url: String) -> void:
	if not _sections.has(asset_type):
		return
	var sec: Dictionary = _sections[asset_type]
	var cards: Dictionary = _thumb_cards.get(asset_type, {})
	for key in cards.keys():
		var c: Button = cards[key]
		if not is_instance_valid(c):
			continue
		c.set_meta("selected", false)
		if not c.has_meta("overlay"):
			continue
		var ov: Panel = c.get_meta("overlay")
		if ov == null:
			continue
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0, 0, 0, 0)
		s.set_corner_radius_all(4)
		ov.add_theme_stylebox_override("panel", s)
	# 高亮选中的
	var sel: Button = cards.get(url, null)
	if sel != null:
		sel.set_meta("selected", true)
		if sel.has_meta("overlay"):
			var sov: Panel = sel.get_meta("overlay")
			if sov != null:
				var ss := StyleBoxFlat.new()
				ss.bg_color = Color(0.88, 0.66, 0.36, 0.15)
				ss.border_color = Color(0.88, 0.66, 0.36, 1.0)
				ss.set_border_width_all(2)
				ss.set_corner_radius_all(4)
				sov.add_theme_stylebox_override("panel", ss)
	sec["selected_url"] = url
	if asset_type == "hero":
		_image_info_label.text = "选中 Hero · 正在获取原图体积…"
		asset_info_requested.emit(url)
	else:
		_image_info_label.text = ""
	_update_apply_button()

func _update_apply_button() -> void:
	var any: bool = false
	for t in _sections.keys():
		var sec: Dictionary = _sections[t]
		if not str(sec["selected_url"]).is_empty():
			any = true
			break
	_apply_button.disabled = not any

# ---------- 应用 ----------

func _on_apply_pressed() -> void:
	if _selected_sgdb_id <= 0 or _apply_active:
		return
	_apply_queue.clear()
	for t in ASSET_TYPES:
		var sec: Dictionary = _sections.get(t, {})
		var url: String = str(sec.get("selected_url", ""))
		if not url.is_empty():
			_apply_queue.append({"type": t, "url": url})
	if _apply_queue.is_empty():
		return
	_apply_index = 0
	_apply_operation_id = "%s:%d" % [_item_id, Time.get_ticks_usec()]
	_apply_active = true
	_apply_button.disabled = true
	_apply_button.text = "应用中…"
	_cancel_button.disabled = true
	_status_label.text = "正在处理选中的素材…"
	_emit_next_apply()

func set_apply_done() -> void:
	_status_label.text = "素材已应用"
	_apply_button.text = "应用选中"
	var operation_id: String = _apply_operation_id
	await get_tree().create_timer(0.85).timeout
	if operation_id == _apply_operation_id and not _apply_active:
		hide()
