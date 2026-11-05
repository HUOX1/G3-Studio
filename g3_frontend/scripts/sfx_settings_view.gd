extends VBoxContainer
## WB-01: UI sound settings page, runtime controls only; persistence owned by main.gd.
signal back_pressed
signal setting_changed(key: String, value: Variant)
signal import_requested(id: String)
signal restore_requested(id: String)

var _toggle: CheckButton
var _slider: HSlider
var _volume_label: Label
var _status: Label
var _rows: Dictionary = {}
var _volume_save_timer: Timer
var _syncing: bool = false

func _ready() -> void:
	visible = false
	add_theme_constant_override("separation", 12)
	var back := Button.new()
	back.text = "← 返回系统"
	back.custom_minimum_size = Vector2(320, 40)
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)
	var header := Label.new()
	header.text = "界面音效管理"
	header.add_theme_font_size_override("font_size", 21)
	add_child(header)
	_toggle = CheckButton.new()
	_toggle.text = "启用界面音效（Ctrl+M）"
	_toggle.toggled.connect(_on_enabled)
	add_child(_toggle)
	var volume_row := HBoxContainer.new()
	add_child(volume_row)
	var caption := Label.new()
	caption.text = "总音量"
	volume_row.add_child(caption)
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = 100
	_slider.step = 1
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(_on_volume)
	_slider.drag_ended.connect(_on_volume_committed)
	_volume_save_timer = Timer.new()
	_volume_save_timer.one_shot = true
	_volume_save_timer.wait_time = 0.45
	_volume_save_timer.timeout.connect(func(): setting_changed.emit("ui_sfx_volume", UISfx.volume))
	add_child(_volume_save_timer)
	volume_row.add_child(_slider)
	_volume_label = Label.new()
	volume_row.add_child(_volume_label)
	for entry in [{"id":"section_switch", "label":"切换主版块 · 机械切换"}, {"id":"boot", "label":"启动图标动画"}, {"id":"detail_out", "label":"退出游戏详情"}, {"id":"card_click", "label":"点击游戏卡片"}, {"id":"game_launch", "label":"开始游戏 · 光盘触及接口"}, {"id":"drive_draw", "label":"开始游戏 · 自动吸入与托盘收缩"}, {"id":"drive_read", "label":"开始游戏 · 读盘旋转"}, {"id":"launch_unavailable", "label":"游戏启动失败 · 无法启动"}, {"id":"sort_cycle", "label":"游戏排序 · 切换方式"}]:
		_add_sound_row(entry["id"], entry["label"])
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	refresh()

func _add_sound_row(id: String, label: String) -> void:
	var title := Label.new()
	title.text = label + "   ·   " + id
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	var source := Label.new()
	add_child(source)
	_rows[id] = source
	var actions := HBoxContainer.new()
	add_child(actions)
	var preview := Button.new()
	preview.text = "试听"
	preview.pressed.connect(func(): UISfx.audition(id))
	actions.add_child(preview)
	var replace := Button.new()
	replace.text = "更换本地文件…"
	replace.pressed.connect(func(): import_requested.emit(id))
	actions.add_child(replace)
	var reset := Button.new()
	reset.text = "恢复默认"
	reset.pressed.connect(func(): restore_requested.emit(id))
	actions.add_child(reset)

func refresh() -> void:
	if _toggle == null:
		return
	_syncing = true
	_toggle.set_pressed_no_signal(UISfx.enabled)
	_slider.set_value_no_signal(roundf(UISfx.volume * 100.0))
	_volume_label.text = "%d%%" % int(_slider.value)
	for id in _rows:
		_rows[id].text = "%s · %s" % [UISfx.effective_source(id), UISfx.effective_filename(id)]
	_syncing = false

func set_status(message: String) -> void:
	if _status != null:
		_status.text = message

func _on_enabled(value: bool) -> void:
	if _syncing:
		return
	UISfx.set_enabled(value)
	setting_changed.emit("ui_sfx", value)

func _on_volume(value: float) -> void:
	if _syncing:
		return
	UISfx.set_volume(value / 100.0)
	_volume_label.text = "%d%%" % int(value)
	_volume_save_timer.start()

func _on_volume_committed(changed: bool) -> void:
	if changed:
		_volume_save_timer.stop()
		setting_changed.emit("ui_sfx_volume", UISfx.volume)
