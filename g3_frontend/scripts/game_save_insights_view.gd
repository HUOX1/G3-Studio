extends VBoxContainer
## Editorial / archive-style, read-only presentation of verified save fields.
## The detail view owns the Hero, floating Logo, navigation and scrolling.

const INK := Color(0.88, 0.91, 0.91)
const MUTED := Color(0.58, 0.69, 0.72)
const SOFT := Color(0.44, 0.53, 0.57)
const ACCENT := Color(0.54, 0.78, 0.76)
const RULE := Color(0.50, 0.63, 0.67, 0.26)

const STAT_NAMES := {
	"vigor": "生命力", "mind": "集中力", "endurance": "耐力", "strength": "力气",
	"dexterity": "灵巧", "intelligence": "智力", "faith": "信仰", "arcane": "感应",
}
const STAT_ORDER := ["vigor", "mind", "endurance", "strength", "dexterity", "intelligence", "faith", "arcane"]
const CLASS_NAMES := {"Wretch": "一贫如洗"}

var _slots: Array = []
var _body: VBoxContainer
var _slot_picker: OptionButton
var _compact: bool = false
var _visual_scale: float = 1.0
var _hero_clearance: Control

func _ready() -> void:
	name = "GameSaveInsights"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 22)
	set_state({"status": "loading"})

func set_compact(compact: bool) -> void:
	if _compact == compact:
		return
	_compact = compact
	set_visual_scale(_visual_scale)
	if not _slots.is_empty() and _slot_picker != null:
		_render_slot(_slot_picker.selected)

func set_visual_scale(scale_value: float) -> void:
	_visual_scale = clampf(scale_value, 0.62, 1.30)
	if _hero_clearance != null:
		# Reserve the Logo's drifting upper-right space without covering the Hero.
		_hero_clearance.custom_minimum_size.y = (190.0 if _compact else 228.0) * _visual_scale

func set_state(payload: Dictionary) -> void:
	if not is_node_ready():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slots.clear()
	_slot_picker = null
	_body = null

	_hero_clearance = Control.new()
	_hero_clearance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero_clearance)
	set_visual_scale(_visual_scale)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 5)
	header.add_child(identity)
	identity.add_child(_label("G3  /  PERSONAL ARCHIVE", 11, ACCENT))
	identity.add_child(_label("存档档案", 29, INK, true))
	identity.add_child(_label("ELDEN RING   ·   只读存档 / LOCAL SAVE", 12, MUTED))

	var status: String = str(payload.get("status", "loading"))
	if status != "ready":
		var message := "正在读取本机存档…"
		if status == "not_found":
			message = str(payload.get("message", "未找到本机存档"))
		elif status == "error":
			message = str(payload.get("message", "存档解析失败"))
		elif status == "unsupported":
			message = str(payload.get("message", "该游戏暂不支持解析"))
		add_child(_note(message, "LOCAL SAVE  /  仅读取 ER0000.sl2，原文件不会被修改"))
		return

	var result: Dictionary = payload.get("data", {})
	var validation: Dictionary = result.get("container_validation", {})
	if not bool(validation.get("checksum_ok", false)):
		add_child(_note("存档完整性校验失败", "为避免误读，本次不展示角色数据。"))
		return

	var records: Array = result.get("slots", [])
	for record in records:
		if record is Dictionary and bool(record.get("active", false)) and bool(record.get("data_present", false)):
			_slots.append(record)
	if _slots.is_empty():
		add_child(_note("没有找到当前活动角色", "未启用的槽位不会计入当前角色档案。"))
		return

	_slot_picker = OptionButton.new()
	_slot_picker.name = "ArchiveSlotPicker"
	_slot_picker.custom_minimum_size = Vector2(160, 35)
	_slot_picker.add_theme_font_size_override("font_size", 13)
	_slot_picker.add_theme_color_override("font_color", INK)
	_slot_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	for record in _slots:
		_slot_picker.add_item("%s  /  SLOT %02d" % [str(record.get("character_name", "")), int(record.get("slot", 0))])
	_slot_picker.item_selected.connect(_render_slot)
	header.add_child(_slot_picker)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 30)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_render_slot(0)

func _render_slot(index: int) -> void:
	if _body == null or index < 0 or index >= _slots.size():
		return
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var record: Dictionary = _slots[index]
	var details: Dictionary = record.get("details", {})
	var seconds_played: int = maxi(0, int(record.get("seconds_played", 0)))
	var time_label: String = "%dh %02dm" % [int(seconds_played / 3600), int((seconds_played % 3600) / 60)]
	var class_key: String = str(details.get("character_class", ""))
	var class_label: String = str(CLASS_NAMES.get(class_key, class_key))

	# The character and level dominate; all other information is secondary.
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 36)
	_body.add_child(portrait_row)
	var character := _stack()
	character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_row.add_child(character)
	character.add_child(_label("01  /  角色档案     CHARACTER FILE", 12, ACCENT))
	character.add_child(_label(str(record.get("character_name", "—")), 76 if not _compact else 52, INK, true))
	character.add_child(_label("起始职业   /   %s" % class_label, 13, MUTED))
	var level := _stack()
	portrait_row.add_child(level)
	level.add_child(_label("LEVEL  /  等级", 12, ACCENT))
	level.add_child(_label(str(int(record.get("level", 0))), 70 if not _compact else 50, INK, true))
	level.add_child(_label("SLOT %02d" % int(record.get("slot", 0)), 11, SOFT))

	_body.add_child(_rule())
	var featured := HBoxContainer.new()
	featured.add_theme_constant_override("separation", 40)
	_body.add_child(featured)
	_feature(featured, "累计游玩   /   PLAYTIME", time_label, "存档内记录", true)
	_feature(featured, "当前卢恩   /   RUNES HELD", _number(int(details.get("runes_held", 0))), "当前持有量，非累计获取", false)

	_body.add_child(_heading("02", "角色属性", "ATTRIBUTES"))
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2 if _compact else 4
	stats_grid.add_theme_constant_override("h_separation", 40)
	stats_grid.add_theme_constant_override("v_separation", 18)
	_body.add_child(stats_grid)
	var stats: Dictionary = details.get("attributes", {})
	for key in STAT_ORDER:
		var cell := _stack()
		stats_grid.add_child(cell)
		var caption_row := HBoxContainer.new()
		caption_row.add_theme_constant_override("separation", 10)
		cell.add_child(caption_row)
		var name_label := _label(str(STAT_NAMES.get(key, key)), 14, MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption_row.add_child(name_label)
		caption_row.add_child(_label(str(int(stats.get(key, 0))), 28, INK, true))
		cell.add_child(_rule())

	_body.add_child(_heading("03", "当前状态", "CURRENT STATUS"))
	var vitals := GridContainer.new()
	vitals.columns = 1 if _compact else 3
	vitals.add_theme_constant_override("h_separation", 40)
	vitals.add_theme_constant_override("v_separation", 20)
	_body.add_child(vitals)
	var vital: Dictionary = details.get("vitals", {})
	_add_vital(vitals, "生命值", "HP", vital.get("hp", {}))
	_add_vital(vitals, "专注值", "FP", vital.get("fp", {}))
	_add_vital(vitals, "精力", "STAMINA", vital.get("stamina", {}))

	_body.add_child(_heading("04", "游玩记录", "PLAY RECORDS"))
	var records_row := HBoxContainer.new()
	records_row.add_theme_constant_override("separation", 44)
	_body.add_child(records_row)
	var death_record := _stack()
	death_record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	records_row.add_child(death_record)
	death_record.add_child(_label("累计死亡记录  /  DEATHS RECORDED", 12, MUTED))
	death_record.add_child(_label(_number(int(details.get("total_deaths_recorded", 0))), 54 if not _compact else 40, INK, true))
	death_record.add_child(_label("来自当前存档的计数", 11, SOFT))
	var technical := _stack()
	technical.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	records_row.add_child(technical)
	technical.add_child(_label("ADDITIONAL RECORDS  /  附加记录", 11, ACCENT))
	_record_line(technical, "背包记录", _number(int((details.get("inventory_held", {}) as Dictionary).get("total_entries", 0))))
	_record_line(technical, "储物箱记录", _number(int((details.get("inventory_storage", {}) as Dictionary).get("total_entries", 0))))
	_record_line(technical, "区域记录", _number(int(details.get("region_list_entries", 0))))

	_body.add_child(_rule())
	_body.add_child(_note("RESEARCH NOTES  /  尚未建立可信映射", "装备名称、首领、任务和地图探索仍需对应 ID 数据。以上条目数不代表物品种类或地图探索比例。"))
	_body.add_child(_label("SOURCE  /  LOCAL PC SAVE    ·    MD5 VERIFIED    ·    READ ONLY", 11, SOFT))

func _feature(parent: HBoxContainer, title: String, value: String, note: String, dominant: bool) -> void:
	var stack := _stack()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(stack)
	stack.add_child(_label(title, 12, MUTED))
	stack.add_child(_label(value, 41 if dominant and not _compact else 33, INK, true))
	stack.add_child(_label(note, 11, SOFT))

func _add_vital(parent: GridContainer, chinese: String, english: String, raw: Variant) -> void:
	var data: Dictionary = raw as Dictionary if raw is Dictionary else {}
	var current: int = int(data.get("current", 0))
	var maximum: int = maxi(0, int(data.get("max", 0)))
	var cell := _stack()
	parent.add_child(cell)
	cell.add_child(_label("%s   /   %s" % [chinese, english], 12, MUTED))
	cell.add_child(_label("%d  /  %d" % [current, maximum], 27, INK, true))
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 3
	bar.max_value = maxf(1.0, float(maximum))
	bar.value = clampi(current, 0, maximum)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = RULE
	bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	bar.add_theme_stylebox_override("fill", fill)
	cell.add_child(bar)

func _record_line(parent: VBoxContainer, chinese: String, value: String) -> void:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var key := _label(chinese, 13, MUTED)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(key)
	line.add_child(_label(value, 17, INK, true))
	parent.add_child(_rule())

func _heading(no: String, chinese: String, english: String) -> VBoxContainer:
	var section := _stack()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	section.add_child(line)
	line.add_child(_label(no, 12, ACCENT))
	line.add_child(_label(chinese, 20, INK, true))
	var en := _label(english, 11, MUTED)
	en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(en)
	section.add_child(_rule())
	return section

func _note(title: String, description: String) -> VBoxContainer:
	var stack := _stack()
	stack.add_child(_label(title, 13, MUTED))
	var body := _label(description, 12, SOFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body)
	return stack

func _stack() -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return stack

func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = RULE
	line.custom_minimum_size.y = 1.0
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _label(value: String, font_size: int, color: Color, prominent: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if prominent:
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.20))
	return label

func _number(value: int) -> String:
	var digits := str(value)
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return result
