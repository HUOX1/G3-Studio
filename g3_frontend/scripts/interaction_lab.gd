extends Control
## G3 交互实验室（COMICS 分区）
##
## 隔离原则：音效页只读 UI 总线、UISfx 状态与 audio_file_loader；
## CRT 页只通过 main.gd 接收 game_section 提供的只读封面样本快照
## （id / title / platform / Texture2D），不持有 GameSection 引用。
## 明确不做：不修改 UISfx 常量、不写 settings.json / library.db、
## 不修改正式卡片 Shader / 动画，不覆盖 assets/audio 下的正式素材。
##
## 动画参数镜像 game_section.gd:173-174 与 _hover_css_bezier()，
## 正式动画若变更，此处必须同步，否则对照失效。

const AUDIO_FILE_LOADER_SCRIPT: Script = preload("res://scripts/audio_file_loader.gd")
const DISC_LOADER_LAB_SCRIPT: Script = preload("res://scripts/disc_loader_lab.gd")
const CRT_ANIMATION_LAB_SCRIPT: Script = preload("res://scripts/crt_animation_lab.gd")
const MATERIAL_LAB_SCRIPT: Script = preload("res://scripts/material_lab.gd")

# ── 详情动画参数（镜像 game_section.gd，请勿在此"优化"）──
const DETAIL_F_DURATION: float = 0.50
const DETAIL_F_START_SCALE: float = 0.97
const BEZIER_X1: float = 0.22
const BEZIER_Y1: float = 0.78
const BEZIER_X2: float = 0.20
const BEZIER_Y2: float = 1.0

const PREVIEW_GAIN_DB: float = -18.0
const CANDIDATE_EXTENSIONS: Array = ["wav"]
const PREVIEW_SIZE: Vector2 = Vector2(520.0, 260.0)

# ── 视觉：沿用 GAMES 分区的深蓝灰语言 ──
const COLOR_BG: Color = Color(0.055, 0.070, 0.095, 1.0)
const COLOR_PANEL: Color = Color(0.10, 0.115, 0.135, 1.0)
const COLOR_TEXT: Color = Color(0.82, 0.86, 0.90, 1.0)
const COLOR_MUTED: Color = Color(0.55, 0.65, 0.78, 1.0)
const COLOR_WARN: Color = Color(1.0, 0.60, 0.52, 1.0)

const FORMAL_SFX: Array = [
	{"id": &"boot", "label": "正式 · boot"},
	{"id": &"detail_in", "label": "正式 · detail_in"},
	{"id": &"detail_out", "label": "正式 · detail_out"},
]

var _candidates: Array = []
var _option_entries: Array = []
var _expand_index: int = 0
var _collapse_index: int = 0
var _active: bool = false

var _player: AudioStreamPlayer
var _anim_tween: Tween

var _list_box: VBoxContainer
var _scroll: ScrollContainer
var _status_label: Label
var _expand_option: OptionButton
var _collapse_option: OptionButton
var _preview_grid: ColorRect
var _preview_detail: PanelContainer
var _audio_page: Control
var _disc_loader_page: Control
var _crt_page: Control
var _material_page: Control
var _active_lab_page: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_player()
	_build_ui()
	_refresh_candidates()


# ══════════════════════════════════════════════════════════
# 生命周期：唯一入口，全部清理集中在这里
# ══════════════════════════════════════════════════════════
func set_lab_active(active: bool) -> void:
	visible = active
	if active != _active:
		_active = active
		if not active:
			_shutdown()
	if _disc_loader_page != null:
		_disc_loader_page.set_page_active(active and _active_lab_page == 1)
	if _crt_page != null:
		_crt_page.set_page_active(active and _active_lab_page == 2)
	if _material_page != null:
		_material_page.set_page_active(active and _active_lab_page == 3)


func set_game_samples(samples: Array[Dictionary]) -> void:
	if _crt_page != null:
		_crt_page.set_game_samples(samples)

func apply_game_theme_palette(palette: Dictionary) -> void:
	if _disc_loader_page != null:
		_disc_loader_page.apply_game_theme_palette(palette)
	if _material_page != null:
		_material_page.apply_game_theme_palette(palette)

func reset_game_theme_palette() -> void:
	if _disc_loader_page != null:
		_disc_loader_page.reset_game_theme_palette()
	if _material_page != null:
		_material_page.reset_game_theme_palette()


func _shutdown() -> void:
	_kill_tween()
	if _player != null:
		_player.stop()
	if _disc_loader_page != null:
		_disc_loader_page.set_page_active(false)
	if _crt_page != null:
		_crt_page.set_page_active(false)
	if _material_page != null:
		_material_page.set_page_active(false)


func _exit_tree() -> void:
	_shutdown()


func _kill_tween() -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null


# ══════════════════════════════════════════════════════════
# 音效
# ══════════════════════════════════════════════════════════
func _build_player() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "LabPreviewPlayer"
	_player.max_polyphony = 1
	if AudioServer.get_bus_index("UI") >= 0:
		_player.bus = "UI"
	add_child(_player)


func _sfx_node():
	return get_node_or_null("/root/UISfx")


## 遵守现有静音与音量：静音或音量为 0 时不发声，并如实告知。
func _audio_allowed() -> bool:
	var sfx = _sfx_node()
	if sfx == null:
		return true
	if not bool(sfx.enabled):
		return false
	return float(sfx.volume) > 0.0


func _current_volume() -> float:
	var sfx = _sfx_node()
	if sfx == null:
		return 0.6
	return clampf(float(sfx.volume), 0.0, 1.0)


func _play_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var label: String = str(entry.get("name", ""))
	var stream: AudioStream = entry.get("stream", null)
	if stream == null:
		_set_status("无法解析：" + label + "（已跳过）", true)
		return
	if not _audio_allowed():
		_set_status("当前已静音（Ctrl+M 恢复），未播放。", true)
		return
	# 单播放器 + 播放前 stop()：同一时间只会有一个候选在响。
	_player.stop()
	_player.stream = stream
	_player.volume_db = PREVIEW_GAIN_DB + linear_to_db(maxf(_current_volume(), 0.0001))
	_player.play()
	_set_status("试听：" + label)


func _play_formal(id: StringName) -> void:
	var sfx = _sfx_node()
	if sfx == null:
		_set_status("UISfx 未就绪，无法试听正式音效。", true)
		return
	if not _audio_allowed():
		_set_status("当前已静音（Ctrl+M 恢复），未播放。", true)
		return
	_player.stop()
	sfx.play(id)
	_set_status("试听正式音效：" + str(id))


func _play_option(index: int) -> void:
	if index <= 0 or index >= _option_entries.size():
		return
	var entry: Dictionary = _option_entries[index]
	if entry.has("formal"):
		_play_formal(entry["formal"])
	else:
		_play_entry(entry)


func _on_stop_pressed() -> void:
	_player.stop()
	_set_status("已停止播放。")


# ══════════════════════════════════════════════════════════
# 候选扫描
# ══════════════════════════════════════════════════════════
func _candidate_dir() -> String:
	var base: String = OS.get_environment("LOCALAPPDATA")
	if base.is_empty():
		base = OS.get_environment("USERPROFILE").path_join("AppData/Local")
	return base.path_join("G3").path_join("lab").path_join("sfx")


func _on_refresh_pressed() -> void:
	_refresh_candidates()


func _refresh_candidates() -> void:
	if _player != null:
		_player.stop()
	_candidates.clear()

	var dir: String = _candidate_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var files: PackedStringArray = DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()

	var names: Array = []
	for file_name in files:
		if CANDIDATE_EXTENSIONS.has(file_name.get_extension().to_lower()):
			names.append(file_name)
	names.sort()

	for file_name in names:
		var abs_path: String = dir.path_join(str(file_name))
		var stream: AudioStream = AUDIO_FILE_LOADER_SCRIPT.load_audio(abs_path, false)
		var length: float = stream.get_length() if stream != null else -1.0
		_candidates.append({
			"name": str(file_name),
			"path": abs_path,
			"stream": stream,
			"length": length,
		})

	_rebuild_list()
	_rebuild_options()

	if _candidates.is_empty():
		_set_status("候选目录为空：把 .wav 放进 " + dir, true)
	else:
		_set_status("已加载 %d 个候选（目录：%s）" % [_candidates.size(), dir])


func _format_length(seconds: float) -> String:
	if seconds < 0.0:
		return "—"
	return "%.2fs" % seconds


# ══════════════════════════════════════════════════════════
# 动画预览
# ══════════════════════════════════════════════════════════
func _on_expand_pressed() -> void:
	_play_transition(true)
	_play_option(_expand_index)


func _on_collapse_pressed() -> void:
	_play_transition(false)
	_play_option(_collapse_index)


func _play_transition(open: bool) -> void:
	_kill_tween()
	var start: float = clampf(_preview_detail.modulate.a, 0.0, 1.0)
	var target: float = 1.0 if open else 0.0
	var duration: float = DETAIL_F_DURATION
	if open:
		# 已完全展开时重播一次完整动画；否则从当前 alpha 平滑反向。
		if start >= 0.999:
			start = 0.0
	else:
		if start <= 0.001:
			_apply_progress(0.0)
			return
		# 与正式实现一致：退出时长按当前可见比例收缩。
		duration = DETAIL_F_DURATION * start

	_anim_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_anim_tween.tween_method(
		func(fraction: float) -> void:
			var eased: float = _bezier(fraction, BEZIER_X1, BEZIER_Y1, BEZIER_X2, BEZIER_Y2)
			_apply_progress(lerpf(start, target, eased)),
		0.0, 1.0, duration
	)
	# 动画自然结束后释放引用；若期间已被新动画替换，则不动新引用。
	var created: Tween = _anim_tween
	created.finished.connect(func() -> void:
		if _anim_tween == created:
			_anim_tween = null)


func _apply_progress(alpha: float) -> void:
	var a: float = clampf(alpha, 0.0, 1.0)
	_preview_grid.modulate.a = 1.0 - a
	_preview_detail.modulate.a = a
	_preview_detail.scale = Vector2.ONE * lerpf(DETAIL_F_START_SCALE, 1.0, a)


## 与 game_section.gd:2071-2084 相同的 cubic-bezier 二分求解（复制而非引用，避免耦合）。
func _bezier(fraction: float, x1: float, y1: float, x2: float, y2: float) -> float:
	var low: float = 0.0
	var high: float = 1.0
	for _iteration in range(20):
		var mid: float = (low + high) * 0.5
		var inv: float = 1.0 - mid
		var curve_x: float = 3.0 * inv * inv * mid * x1 + 3.0 * inv * mid * mid * x2 + mid * mid * mid
		if curve_x < fraction:
			low = mid
		else:
			high = mid
	var t: float = (low + high) * 0.5
	var inv_t: float = 1.0 - t
	return 3.0 * inv_t * inv_t * t * y1 + 3.0 * inv_t * t * t * y2 + t * t * t


# ══════════════════════════════════════════════════════════
# UI 构建
# ══════════════════════════════════════════════════════════
func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COLOR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 34)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	column.add_child(_make_label("交互实验室", 20, COLOR_TEXT))
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	tabs.add_child(_make_button("音效与动画", func() -> void: _show_lab_page(0)))
	tabs.add_child(_make_button("启动装置实验", func() -> void: _show_lab_page(1)))
	tabs.add_child(_make_button("CRT 动画实验", func() -> void: _show_lab_page(2)))
	tabs.add_child(_make_button("复古工业材质", func() -> void: _show_lab_page(3)))
	column.add_child(_make_label("COMICS · 音效、启动装置、CRT 与复古工业材质实验；实验原型不触发真实游戏", 12, COLOR_MUTED))

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	column.add_child(spacer)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 44)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	_audio_page = row
	_disc_loader_page = DISC_LOADER_LAB_SCRIPT.new()
	_disc_loader_page.visible = false
	_disc_loader_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_disc_loader_page)
	_crt_page = CRT_ANIMATION_LAB_SCRIPT.new()
	_crt_page.visible = false
	_crt_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_crt_page)
	_material_page = MATERIAL_LAB_SCRIPT.new()
	_material_page.visible = false
	_material_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_material_page)
	row.add_child(_build_audio_column())
	row.add_child(_build_preview_column())

	_status_label = _make_label("就绪。", 12, COLOR_MUTED)
	column.add_child(_status_label)


func _show_lab_page(page_index: int) -> void:
	_active_lab_page = clampi(page_index, 0, 3)
	if _audio_page != null:
		_audio_page.visible = _active_lab_page == 0
	if _disc_loader_page != null:
		_disc_loader_page.visible = _active_lab_page == 1
	if _crt_page != null:
		_crt_page.visible = _active_lab_page == 2
	if _material_page != null:
		_material_page.visible = _active_lab_page == 3
	if _status_label != null:
		_status_label.visible = _active_lab_page == 0
	if _active_lab_page != 0:
		_shutdown()
	if _disc_loader_page != null:
		_disc_loader_page.set_page_active(_active and _active_lab_page == 1)
	if _crt_page != null:
		_crt_page.set_page_active(_active and _active_lab_page == 2)
	if _material_page != null:
		_material_page.set_page_active(_active and _active_lab_page == 3)
	if _active_lab_page == 0:
		_set_status("就绪。")


func _build_audio_column() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(400.0, 0.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)

	box.add_child(_make_label("音效候选", 14, COLOR_TEXT))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0.0, 210.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# 不撑满整列：列表按内容高度收住，下面的按钮紧跟其后，避免被推到窗口底部。
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list_box)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	actions.add_child(_make_button("刷新列表", _on_refresh_pressed))
	actions.add_child(_make_button("停止播放", _on_stop_pressed))

	box.add_child(_make_label("正式音效（只读对照，不会被覆盖）", 12, COLOR_MUTED))
	var formal_row: HBoxContainer = HBoxContainer.new()
	formal_row.add_theme_constant_override("separation", 8)
	box.add_child(formal_row)
	for item in FORMAL_SFX:
		var id: StringName = item["id"]
		formal_row.add_child(_make_button(str(item["label"]), func() -> void: _play_formal(id)))

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 22.0)
	box.add_child(gap)
	box.add_child(_make_label("用法", 12, COLOR_TEXT))
	box.add_child(_make_label("· 把 .wav 放进上方目录，点「刷新列表」即可出现", 11, COLOR_MUTED))
	box.add_child(_make_label("· 展开音 / 收起音只存于本次运行，不写入任何配置", 11, COLOR_MUTED))
	box.add_child(_make_label("· 音量跟随系统设置；Ctrl+M 全局静音", 11, COLOR_MUTED))
	box.add_child(_make_label("· 正式音效仅试听，不会被覆盖或替换", 11, COLOR_MUTED))

	return box


func _build_preview_column() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(PREVIEW_SIZE.x, 0.0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)

	box.add_child(_make_label("动画预览", 14, COLOR_TEXT))

	var area: Control = Control.new()
	area.custom_minimum_size = PREVIEW_SIZE
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(area)

	_preview_grid = ColorRect.new()
	_preview_grid.color = COLOR_PANEL
	_preview_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_preview_grid)
	_preview_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for i in range(8):
		var tile: ColorRect = ColorRect.new()
		tile.color = Color(0.145, 0.175, 0.215, 1.0)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.position = Vector2(26.0 + float(i % 4) * 122.0, 44.0 + float(i / 4) * 94.0)
		tile.size = Vector2(104.0, 76.0)
		_preview_grid.add_child(tile)

	_preview_detail = PanelContainer.new()
	_preview_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.125, 0.145, 0.175, 1.0)
	style.border_color = Color(0.30, 0.38, 0.46, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	_preview_detail.add_theme_stylebox_override("panel", style)
	area.add_child(_preview_detail)
	_preview_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var detail_box: VBoxContainer = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 6)
	detail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_detail.add_child(detail_box)

	var title: Label = _make_label("详情预览", 16, COLOR_TEXT)
	detail_box.add_child(title)
	detail_box.add_child(_make_label("0.50s · 0.97 → 1.00 · cubic-bezier(.22, .78, .20, 1)", 11, COLOR_MUTED))
	for i in range(3):
		var line: ColorRect = ColorRect.new()
		line.color = Color(0.20, 0.24, 0.29, 1.0)
		line.custom_minimum_size = Vector2(0.0, 2.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_box.add_child(line)

	_preview_detail.pivot_offset = PREVIEW_SIZE * 0.5
	_preview_detail.modulate.a = 0.0
	_preview_detail.scale = Vector2.ONE * DETAIL_F_START_SCALE

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	buttons.add_child(_make_button("展开", _on_expand_pressed))
	buttons.add_child(_make_button("收起", _on_collapse_pressed))

	var sound_row: HBoxContainer = HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 10)
	box.add_child(sound_row)

	sound_row.add_child(_make_label("展开音", 12, COLOR_MUTED))
	_expand_option = OptionButton.new()
	_expand_option.add_theme_font_size_override("font_size", 12)
	_expand_option.focus_mode = Control.FOCUS_NONE
	# 按内容宽度收住，不要横跨整列。
	_expand_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_expand_option.custom_minimum_size = Vector2(160.0, 0.0)
	_expand_option.item_selected.connect(func(index: int) -> void: _expand_index = index)
	sound_row.add_child(_expand_option)

	sound_row.add_child(_make_label("收起音", 12, COLOR_MUTED))
	_collapse_option = OptionButton.new()
	_collapse_option.add_theme_font_size_override("font_size", 12)
	_collapse_option.focus_mode = Control.FOCUS_NONE
	_collapse_option.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_collapse_option.custom_minimum_size = Vector2(160.0, 0.0)
	_collapse_option.item_selected.connect(func(index: int) -> void: _collapse_index = index)
	sound_row.add_child(_collapse_option)

	return box


func _rebuild_list() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()

	if _candidates.is_empty():
		_list_box.add_child(_make_label("（目录为空，放入 .wav 后点刷新）", 12, COLOR_MUTED))
		_fit_scroll_height()
		return

	for entry in _candidates:
		var text: String = "%s    %s" % [str(entry["name"]), _format_length(float(entry["length"]))]
		var btn: Button = _make_button(text, func() -> void: _play_entry(entry))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry["stream"] == null:
			btn.disabled = true
			btn.text = text + "    [损坏]"
		_list_box.add_child(btn)

	_fit_scroll_height()


## 列表按内容高度收住（不超过上限），避免条目少时留出一大块空白。
func _fit_scroll_height() -> void:
	if _scroll == null or _list_box == null:
		return
	var total: float = 0.0
	var count: int = 0
	for child in _list_box.get_children():
		if child is Control:
			total += (child as Control).get_combined_minimum_size().y
			count += 1
	total += float(maxi(0, count - 1)) * 4.0
	_scroll.custom_minimum_size = Vector2(0.0, clampf(total + 6.0, 48.0, 240.0))


func _rebuild_options() -> void:
	_option_entries.clear()
	_option_entries.append({})
	_expand_option.clear()
	_collapse_option.clear()
	_expand_option.add_item("（无声音）")
	_collapse_option.add_item("（无声音）")

	for entry in _candidates:
		var label: String = "%s  %s" % [str(entry["name"]), _format_length(float(entry["length"]))]
		_expand_option.add_item(label)
		_collapse_option.add_item(label)
		_option_entries.append(entry)

	for item in FORMAL_SFX:
		_expand_option.add_item(str(item["label"]))
		_collapse_option.add_item(str(item["label"]))
		_option_entries.append({"formal": item["id"], "name": str(item["label"])})

	_expand_index = clampi(_expand_index, 0, _option_entries.size() - 1)
	_collapse_index = clampi(_collapse_index, 0, _option_entries.size() - 1)
	_expand_option.select(_expand_index)
	_collapse_option.select(_collapse_index)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String, action: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 13)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(action)
	return btn


func _set_status(text: String, warn: bool = false) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", COLOR_WARN if warn else COLOR_MUTED)
