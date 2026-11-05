extends RefCounted

const MOVIE_INFO_LEFT_RATIO: float = 0.33
const MOVIE_INFO_RIGHT_MARGIN: float = 60.0
const MOVIE_TITLE_FIXED_RATIO: float = 0.11
const MOVIE_DESC_FIXED_RATIO: float = 0.20
const MOVIE_META_GAP_ABOVE_TITLE: float = 16.0
const MOVIE_DESC_BOTTOM_RESERVE: float = 20.0
const UI_BASE_WIDTH: float = 1600.0
const UI_BASE_HEIGHT: float = 900.0


# UI-S1: 只构建电影信息节点；数据、字体、动画和位置仍由 main.gd 管理。
# 保持节点添加顺序和原始样式，不额外增加父容器。
func build(parent: Control) -> Dictionary:
	var title: Label = Label.new()
	title.visible = false
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(title)

	var meta: Label = Label.new()
	meta.visible = false
	meta.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68, 1))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(meta)

	var genres: Label = Label.new()
	genres.visible = false
	genres.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72, 1))
	genres.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(genres)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(scroll)

	var vsb: VScrollBar = scroll.get_v_scroll_bar()
	if vsb != null:
		vsb.custom_minimum_size = Vector2(0.0, 0.0)
		var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
		vsb.add_theme_stylebox_override("scroll", empty_style)
		vsb.add_theme_stylebox_override("grabber", empty_style)
		vsb.add_theme_stylebox_override("grabber_highlight", empty_style)
		vsb.add_theme_stylebox_override("grabber_pressed", empty_style)

	var desc_vbox: VBoxContainer = VBoxContainer.new()
	desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(desc_vbox)

	var description: Label = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80, 1))
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_vbox.add_child(description)

	return {
		"title": title,
		"meta": meta,
		"genres": genres,
		"scroll": scroll,
		"description": description,
	}

# UI-S6e: 仅格式化信息区展示文字；不读写电影数据，也不触碰界面状态。
func format_content(movie: Dictionary) -> Dictionary:
	var year_raw: Variant = movie.get("release_year", "")
	var year: String = ""
	if year_raw != null:
		year = str(year_raw).strip_edges()
		if year.ends_with(".0"):
			year = year.substr(0, year.length() - 2)
	var tagline: String = str(movie.get("tagline", "")).strip_edges()
	return {
		"title": str(movie.get("title", "")),
		"year": year,
		"meta_line": format_meta_line(movie),
		"description": str(movie.get("description", "")).strip_edges(),
		"tagline": "“%s”" % tagline if not tagline.is_empty() else "",
	}

func format_meta_line(movie: Dictionary) -> String:
	var parts: Array[String] = []
	var genres_str: String = str(movie.get("genres", "")).strip_edges()
	if not genres_str.is_empty():
		parts.append("▸ " + genres_str)
	var runtime_min: int = int(movie.get("runtime_minutes", 0))
	var media_type: String = str(movie.get("media_type", "movie"))
	if runtime_min > 0:
		var runtime_text: String
		if media_type == "series":
			runtime_text = "%d分钟/集" % runtime_min
		else:
			var hours: int = runtime_min / 60
			var mins: int = runtime_min % 60
			if hours > 0 and mins > 0:
				runtime_text = "%d小时%d分" % [hours, mins]
			elif hours > 0:
				runtime_text = "%d小时" % hours
			else:
				runtime_text = "%d分钟" % mins
		parts.append("◷ " + runtime_text)
	var vote: float = float(movie.get("vote_average", 0.0))
	if vote > 0.05:
		parts.append("★ %.1f" % vote)
	else:
		parts.append("★ —")
	return " · ".join(parts)

# UI-S6g: movie info geometry and typography; main owns lifecycle and visibility.
func update_layout(vp: Vector2, font_manager: Variant, movie_info_title: Label, movie_info_meta: Label, movie_info_genres: Label, movie_desc_label: Label, movie_desc_scroll: ScrollContainer, info_offset: float) -> void:
	if vp.x <= 0.0 or vp.y <= 0.0:
		return

	var raw: float = min(vp.x / UI_BASE_WIDTH, vp.y / UI_BASE_HEIGHT)
	var ui_scale: float = clampf(raw, 0.70, 1.30)
	var font_scale: float = clampf(raw, 0.90, 1.30)
	var base_title := 34
	var base_year := 14
	var base_meta := 14
	var base_desc := 16
	if font_manager != null:
		base_title = font_manager.get_size_for("movie_title", 34)
		base_year = font_manager.get_size_for("movie_year", 14)
		base_meta = font_manager.get_size_for("movie_meta", 14)
		base_desc = font_manager.get_size_for("movie_desc", 16)

	movie_info_title.add_theme_font_size_override("font_size", int(float(base_title) * font_scale))
	movie_info_meta.add_theme_font_size_override("font_size", int(float(base_year) * font_scale))
	movie_info_genres.add_theme_font_size_override("font_size", int(float(base_meta) * font_scale))
	movie_desc_label.add_theme_font_size_override("font_size", int(float(base_desc) * font_scale))

	var info_left: float = vp.x * MOVIE_INFO_LEFT_RATIO
	var right_ratio: float = MOVIE_INFO_RIGHT_MARGIN / UI_BASE_WIDTH
	var info_right: float = vp.x * (1.0 - right_ratio)
	var block_width: float = info_right - info_left

	var title_y: float = vp.y * MOVIE_TITLE_FIXED_RATIO
	var desc_y: float = vp.y * (1.0 - MOVIE_DESC_FIXED_RATIO)

	# 容器高度 / 文字间距跟字号曲线走（小窗口下 ui_scale 会缩得过小，装不下字）
	var title_h: float = 50.0 * font_scale
	var meta_box_h: float = 24.0 * font_scale
	var meta_gap: float = MOVIE_META_GAP_ABOVE_TITLE * font_scale

	movie_info_title.position = Vector2(info_left, title_y)
	movie_info_title.size = Vector2(block_width, title_h)
	movie_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var font: Font = movie_info_title.get_theme_font("font")
	var font_size: int = movie_info_title.get_theme_font_size("font_size")
	var title_text: String = movie_info_title.text
	var measured: Vector2 = Vector2.ZERO
	if font != null and not title_text.is_empty():
		measured = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var title_left_x: float = info_left + block_width - measured.x
	if title_left_x < info_left:
		title_left_x = info_left

	movie_info_meta.position = Vector2(title_left_x, title_y - meta_gap)
	movie_info_meta.size = Vector2(block_width, meta_box_h)
	movie_info_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	movie_info_genres.position = Vector2(info_left, title_y + title_h)
	movie_info_genres.size = Vector2(block_width, meta_box_h)
	movie_info_genres.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var desc_height: float = vp.y - desc_y - MOVIE_DESC_BOTTOM_RESERVE * font_scale
	# 至少放得下一行（行高 ≈ 1.6 倍字号）
	var desc_font: int = movie_desc_label.get_theme_font_size("font_size")
	var min_desc: float = 1.6 * float(maxi(desc_font, 1))
	if desc_height < min_desc:
		desc_height = min_desc
	if movie_desc_scroll != null:
		movie_desc_scroll.position = Vector2(info_left, desc_y + info_offset)
		movie_desc_scroll.size = Vector2(block_width, desc_height)
	movie_desc_label.custom_minimum_size = Vector2(block_width - 14.0 * ui_scale, 0.0)
	movie_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
