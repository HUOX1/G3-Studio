extends Node

const BUILDER: Script = preload("res://scripts/movie_info_view_builder.gd")
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[FAIL] " + label)

func _run() -> void:
	var builder: RefCounted = BUILDER.new()
	var info: Dictionary = builder.format_content({})
	var original: Dictionary = {"title": "A", "runtime_minutes": 30}
	builder.format_content(original)
	_check(info["title"] == "", "empty title")
	_check(info["year"] == "", "empty year")
	_check(info["description"] == "", "empty description")
	_check(info["tagline"] == "", "empty tagline")
	_check(info["meta_line"] == "★ —", "empty meta rating placeholder")
	_check(builder.format_content({"release_year": 2024})["year"] == "2024", "year int")
	_check(builder.format_content({"release_year": 2024.0})["year"] == "2024", "year float")
	_check(builder.format_content({"release_year": "2024.0"})["year"] == "2024", "year string decimal")
	_check(builder.format_content({"release_year": " 2024 "})["year"] == "2024", "year trimmed")
	_check(builder.format_content({"release_year": null})["year"] == "", "year null")
	_check(builder.format_content({"release_year": "2024.5"})["year"] == "2024.5", "year nonzero decimal")
	_check(builder.format_content({"title": " A "})["title"] == " A ", "title unchanged whitespace")
	_check(builder.format_content({"description": " A "})["description"] == "A", "description trimmed")
	_check(builder.format_content({"tagline": " Hello "})["tagline"] == "“Hello”", "tagline trimmed wrapped")
	_check(builder.format_content({"tagline": "   "})["tagline"] == "", "tagline blank")
	_check(builder.format_content({"tagline": "A/B"})["tagline"] == "“A/B”", "tagline quote preserved")
	_check(builder.format_meta_line({"genres": "科幻"}) == "▸ 科幻 · ★ —", "genres only")
	_check(builder.format_meta_line({"genres": "  剧情  "}) == "▸ 剧情 · ★ —", "genres trimmed")
	_check(builder.format_meta_line({"genres": "  "}) == "★ —", "genres blank omitted")
	_check(builder.format_meta_line({"runtime_minutes": 1}) == "◷ 1分钟 · ★ —", "runtime 1")
	_check(builder.format_meta_line({"runtime_minutes": 59}) == "◷ 59分钟 · ★ —", "runtime 59")
	_check(builder.format_meta_line({"runtime_minutes": 60}) == "◷ 1小时 · ★ —", "runtime 60")
	_check(builder.format_meta_line({"runtime_minutes": 61}) == "◷ 1小时1分 · ★ —", "runtime 61")
	_check(builder.format_meta_line({"runtime_minutes": 120}) == "◷ 2小时 · ★ —", "runtime 120")
	_check(builder.format_meta_line({"runtime_minutes": 125}) == "◷ 2小时5分 · ★ —", "runtime 125")
	_check(builder.format_meta_line({"runtime_minutes": 0}) == "★ —", "runtime 0")
	_check(builder.format_meta_line({"runtime_minutes": -1}) == "★ —", "runtime negative")
	_check(builder.format_meta_line({"media_type": "series", "runtime_minutes": 90}) == "◷ 90分钟/集 · ★ —", "series runtime")
	_check(builder.format_meta_line({"media_type": "movie", "runtime_minutes": 90}) == "◷ 1小时30分 · ★ —", "movie runtime")
	_check(builder.format_meta_line({"vote_average": 0.05}) == "★ —", "rating 0.05")
	_check(builder.format_meta_line({"vote_average": 0.06}) == "★ 0.1", "rating positive")
	_check(builder.format_meta_line({"vote_average": 8.75}) == "★ 8.8", "rating one decimal")
	_check(builder.format_meta_line({"vote_average": 10.0}) == "★ 10.0", "rating 10")
	_check(builder.format_meta_line({"genres": "动作", "runtime_minutes": 125, "vote_average": 8.0}) == "▸ 动作 · ◷ 2小时5分 · ★ 8.0", "full order")
	_check(builder.format_content({"title": "片名", "release_year": "2020.0", "genres": "科幻", "runtime_minutes": 60, "vote_average": 9, "description": "  简介  ", "tagline": "标语"})["meta_line"] == "▸ 科幻 · ◷ 1小时 · ★ 9.0", "format content full")
	_check(original == {"title": "A", "runtime_minutes": 30}, "input not modified")
	if failures == 0 and checks == 36:
		print("MOVIE INFO CONTENT PRESENTATION CONTRACT PASS: 36 checks")
	else:
		push_error("MOVIE INFO CONTENT PRESENTATION CONTRACT FAIL: %d/%d" % [failures, checks])
	get_tree().quit(0 if failures == 0 and checks == 36 else 1)
