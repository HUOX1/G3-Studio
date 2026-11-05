extends Node

const BUILDER: Script = preload("res://scripts/library_scan_import_payload_builder.gd")
const EXPECTED_BEFORE_FINAL: int = 58

var checks: int = 0
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)

func _run() -> void:
	var cases: Array[Dictionary] = [
		{
			"platform": "emulator",
			"row": {"suggested_title": "  Retro  ", "rom_path": "  C:/roms/a.rom  ", "platform_tag": "NES", "launch_exe": "emu.exe", "launch_args": "--run", "working_directory": "C:/emu"},
			"invalid": {"suggested_title": "", "rom_path": "C:/roms/a.rom"},
			"expected": {"title": "Retro", "platform": "NES", "profile_type": "emulator", "video_path": "C:/roms/a.rom", "content_path": "C:/roms/a.rom", "launch_exe": "emu.exe", "launch_args": "--run", "working_directory": "C:/emu", "cover_source": ""},
		},
		{
			"platform": "steam",
			"row": {"name": "  Steam Game  ", "steam_appid": "42"},
			"invalid": {"name": "Game", "steam_appid": 0},
			"expected": {"title": "Steam Game", "platform": "Steam", "profile_type": "direct", "launch_exe": "", "video_path": "", "content_path": "", "source": "steam", "steam_appid": 42, "cover_source": ""},
		},
		{
			"platform": "gog",
			"row": {"title": "  GOG Game  ", "game_id": "  gog-1  ", "launch_exe": "gog.exe", "working_directory": "C:/gog"},
			"invalid": {"title": "GOG Game", "game_id": " "},
			"expected": {"title": "GOG Game", "platform": "GOG", "profile_type": "direct", "launch_exe": "gog.exe", "working_directory": "C:/gog", "video_path": "", "content_path": "", "source": "gog", "external_id": "gog-1", "cover_source": ""},
		},
		{
			"platform": "epic",
			"row": {"title": "  Epic Game  ", "app_name": "  epic-1  ", "launch_exe": "epic.exe", "namespace_id": "ns", "artifact_id": "artifact"},
			"invalid": {"title": "Epic Game", "app_name": " "},
			"expected": {"title": "Epic Game", "platform": "Epic", "profile_type": "direct", "launch_exe": "epic.exe", "video_path": "", "content_path": "", "source": "epic", "external_id": "epic-1", "namespace_id": "ns", "artifact_id": "artifact", "cover_source": ""},
		},
		{
			"platform": "uplay",
			"row": {"title": "  Uplay Game  ", "game_id": "  uplay-1  ", "launch_exe": "uplay.exe", "working_directory": "C:/uplay"},
			"invalid": {"title": "Uplay Game", "game_id": " "},
			"expected": {"title": "Uplay Game", "platform": "Uplay", "profile_type": "direct", "launch_exe": "uplay.exe", "working_directory": "C:/uplay", "video_path": "", "content_path": "", "source": "uplay", "external_id": "uplay-1", "cover_source": ""},
		},
		{
			"platform": "rockstar",
			"row": {"title": "  Rockstar Game  ", "game_id": "  rockstar-1  ", "launch_exe": "rockstar.exe", "working_directory": "C:/rockstar"},
			"invalid": {"title": "Rockstar Game", "game_id": " "},
			"expected": {"title": "Rockstar Game", "platform": "Rockstar", "profile_type": "direct", "launch_exe": "rockstar.exe", "working_directory": "C:/rockstar", "video_path": "", "content_path": "", "source": "rockstar", "external_id": "rockstar-1", "cover_source": ""},
		},
	]
	for test_case: Dictionary in cases:
		var platform: String = str(test_case["platform"])
		var row: Dictionary = test_case["row"]
		var invalid: Dictionary = test_case["invalid"]
		var already: Dictionary = row.duplicate()
		already["already_exists"] = true
		var mixed: Array = [row, already, invalid, "not a dictionary"]
		var built: Array[Dictionary] = BUILDER.build(platform, mixed)
		_check(built.size() == 1, platform + " one valid payload")
		_check(built.size() == 1 and built[0] == test_case["expected"], platform + " exact create payload")
		_check(BUILDER.count_existing(mixed) == 1, platform + " existing count")
		_check(BUILDER.build(platform, ["bad"]).is_empty(), platform + " non-dictionary ignored")
		_check(BUILDER.build(platform, [already]).is_empty(), platform + " existing ignored")
		_check(BUILDER.build(platform, [invalid]).is_empty(), platform + " invalid fields ignored")
		_check(BUILDER.build(platform, []).is_empty(), platform + " empty input")
		_check(BUILDER.build(platform, mixed) == built, platform + " deterministic payloads")
	_check(BUILDER.build("unknown", [{"title": "x"}]).is_empty(), "unknown platform rejected")
	var psn_items: Array = [
		{"title": "PSN Game", "english_name": "English Title", "platform": "PS5", "external_id": "np-123", "psn_playtime_seconds": 456},
		{"title": "Already Exists", "already_exists": true},
		"not a dictionary",
	]
	var psn_payloads: Array[Dictionary] = BUILDER.build("psn", psn_items)
	_check(psn_payloads.size() == 1, "PSN one payload; existing and malformed rows ignored")
	_check(psn_payloads.size() == 1 and psn_payloads[0] == {
		"title": "PSN Game", "english_name": "English Title", "platform": "PS5",
		"profile_type": "direct", "launch_exe": "", "video_path": "", "content_path": "",
		"source": "psn", "external_id": "np-123", "psn_playtime_seconds": 456,
	}, "PSN exact create payload")
	_check(BUILDER.build("psn", [{"title": "Already Exists", "already_exists": true}]).is_empty(), "PSN existing row skipped")
	_check(BUILDER.build("psn", ["not a dictionary"]).is_empty(), "PSN malformed row ignored")
	_check(BUILDER.build("psn", []).is_empty(), "PSN empty input")
	_check(BUILDER.count_existing([]) == 0, "empty existing count")
	_check(BUILDER.count_existing([{"already_exists": true}, {"already_exists": true}, "bad"]) == 2, "existing count includes skipped rows")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("LIBRARY_SCAN_IMPORT_PAYLOAD_BUILDER_SCRIPT.build"), "main delegates payload conversion")
	_check(main_source.contains("LIBRARY_SCAN_IMPORT_PAYLOAD_BUILDER_SCRIPT.build(platform, items)"), "main delegates platform payload conversion")
	_check(checks == EXPECTED_BEFORE_FINAL, "expected check count")
	if failures == 0:
		print("LIBRARY SCAN IMPORT PAYLOAD BUILDER CONTRACT PASS: %d checks" % checks)
	else:
		push_error("LIBRARY SCAN IMPORT PAYLOAD BUILDER CONTRACT FAIL: %d/%d failed" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
