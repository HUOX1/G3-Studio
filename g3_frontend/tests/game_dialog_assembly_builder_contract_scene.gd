extends Node

const BUILDER: Script = preload("res://scripts/game_dialog_assembly_builder.gd")
const EXPECTED_CHECKS: int = 56
var checks: int = 0
var failures: int = 0
var _sgdb_apply_event: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _noop(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	pass

func _on_sgdb_apply_context(item_id: String, sgdb_id: int, asset_type: String, url: String) -> void:
	_sgdb_apply_event = {"item_id": item_id, "sgdb_id": sgdb_id, "asset_type": asset_type, "url": url}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)

func _run() -> void:
	var ui := Control.new()
	add_child(ui)
	var platforms: Array[String] = ["PC", "Steam", "PS5"]
	var entry_callbacks: Dictionary = {}
	entry_callbacks["_on_game_create_requested"] = Callable(self, "_noop")
	entry_callbacks["_on_paste_import_apply"] = Callable(self, "_noop")
	var entry_start: int = get_child_count()
	var entry: Dictionary = BUILDER.new().build_entry(self, platforms, entry_callbacks)
	var callbacks: Dictionary = {}
	callbacks["_on_sgdb_search_requested"] = Callable(self, "_noop")
	callbacks["_on_sgdb_assets_requested"] = Callable(self, "_noop")
	callbacks["_on_sgdb_apply_requested"] = Callable(self, "_on_sgdb_apply_context")
	callbacks["_on_library_scan_requested"] = Callable(self, "_noop")
	callbacks["_on_library_scan_import_requested"] = Callable(self, "_noop")
	callbacks["_on_library_scan_dialog_closed"] = Callable(self, "_noop")
	callbacks["_on_game_manage_action"] = Callable(self, "_noop")
	callbacks["_on_steam_search_requested"] = Callable(self, "_noop")
	callbacks["_on_steam_apply_requested"] = Callable(self, "_noop")
	callbacks["_on_game_metadata_save_requested"] = Callable(self, "_noop")
	callbacks["_on_game_launch_save_requested"] = Callable(self, "_noop")
	callbacks["_on_playtime_save_requested"] = Callable(self, "_noop")
	callbacks["_on_game_remove_confirmed"] = Callable(self, "_noop")
	var manage_start: int = get_child_count()
	var managed: Dictionary = BUILDER.new().build_management(self, ui, platforms, callbacks)
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(entry.size() == 2, "two entry nodes")
	_check(managed.size() == 8, "eight management nodes")
	_check(entry.has("game_create_dialog") and entry["game_create_dialog"] != null, "entry game_create_dialog returned")
	_check(entry.has("game_paste_import_dialog") and entry["game_paste_import_dialog"] != null, "entry game_paste_import_dialog returned")
	_check(managed.has("game_scraper_dialog") and managed["game_scraper_dialog"] != null, "management game_scraper_dialog returned")
	_check(managed.has("library_scan_dialog") and managed["library_scan_dialog"] != null, "management library_scan_dialog returned")
	_check(managed.has("game_manage_menu") and managed["game_manage_menu"] != null, "management game_manage_menu returned")
	_check(managed.has("steam_search_dialog") and managed["steam_search_dialog"] != null, "management steam_search_dialog returned")
	_check(managed.has("game_metadata_dialog") and managed["game_metadata_dialog"] != null, "management game_metadata_dialog returned")
	_check(managed.has("game_launch_dialog") and managed["game_launch_dialog"] != null, "management game_launch_dialog returned")
	_check(managed.has("playtime_edit_dialog") and managed["playtime_edit_dialog"] != null, "management playtime_edit_dialog returned")
	_check(managed.has("game_remove_confirm") and managed["game_remove_confirm"] != null, "management game_remove_confirm returned")
	_check(entry["game_create_dialog"].get_parent() == self, "entry game_create_dialog owner")
	_check(entry["game_paste_import_dialog"].get_parent() == self, "entry game_paste_import_dialog owner")
	_check(managed["game_scraper_dialog"].get_parent() == self, "management game_scraper_dialog parent")
	_check(managed["library_scan_dialog"].get_parent() == self, "management library_scan_dialog parent")
	_check(managed["game_manage_menu"].get_parent() == ui, "management game_manage_menu parent")
	_check(managed["steam_search_dialog"].get_parent() == self, "management steam_search_dialog parent")
	_check(managed["game_metadata_dialog"].get_parent() == self, "management game_metadata_dialog parent")
	_check(managed["game_launch_dialog"].get_parent() == self, "management game_launch_dialog parent")
	_check(managed["playtime_edit_dialog"].get_parent() == self, "management playtime_edit_dialog parent")
	_check(managed["game_remove_confirm"].get_parent() == self, "management game_remove_confirm parent")
	_check(get_child(entry_start) == entry["game_create_dialog"], "entry order create")
	_check(get_child(entry_start + 1) == entry["game_paste_import_dialog"], "entry order paste")
	_check(get_child(manage_start + 0) == managed["game_scraper_dialog"], "management owner order game_scraper_dialog")
	_check(get_child(manage_start + 1) == managed["library_scan_dialog"], "management owner order library_scan_dialog")
	_check(get_child(manage_start + 2) == managed["steam_search_dialog"], "management owner order steam_search_dialog")
	_check(get_child(manage_start + 3) == managed["game_metadata_dialog"], "management owner order game_metadata_dialog")
	_check(get_child(manage_start + 4) == managed["game_launch_dialog"], "management owner order game_launch_dialog")
	_check(get_child(manage_start + 5) == managed["playtime_edit_dialog"], "management owner order playtime_edit_dialog")
	_check(get_child(manage_start + 6) == managed["game_remove_confirm"], "management owner order game_remove_confirm")
	_check(ui.get_child(0) == managed["game_manage_menu"], "game menu in ui")
	_check(managed["game_remove_confirm"].title == "移除游戏档案", "remove dialog title")
	_check(managed["game_remove_confirm"].ok_button_text == "移除", "remove confirm label")
	_check(managed["game_remove_confirm"].cancel_button_text == "取消", "remove cancel label")
	_check(main_source.contains("GAME_DIALOG_ASSEMBLY_BUILDER_SCRIPT.new().build_entry("), "main delegates entry")
	_check(main_source.contains("GAME_DIALOG_ASSEMBLY_BUILDER_SCRIPT.new().build_management("), "main delegates management")
	_check(not main_source.contains("game_scraper_dialog = GAME_SCRAPER_DIALOG_SCRIPT.new()"), "no inline scraper")
	_check(not main_source.contains("game_remove_confirm = ConfirmationDialog.new()"), "no inline game removal dialog")
	_check(entry["game_create_dialog"].create_requested.is_connected(Callable(self, "_noop")), "connected game_create_dialog create_requested")
	_check(entry["game_paste_import_dialog"].apply_requested.is_connected(Callable(self, "_noop")), "connected game_paste_import_dialog apply_requested")
	_check(managed["game_scraper_dialog"].search_requested.is_connected(Callable(self, "_noop")), "connected game_scraper_dialog search_requested")
	_check(managed["game_scraper_dialog"].assets_requested.is_connected(Callable(self, "_noop")), "connected game_scraper_dialog assets_requested")
	_check(managed["game_scraper_dialog"].apply_requested.is_connected(Callable(self, "_on_sgdb_apply_context")), "connected game_scraper_dialog apply_requested")
	_check(managed["library_scan_dialog"].scan_requested.is_connected(Callable(self, "_noop")), "connected library_scan_dialog scan_requested")
	_check(managed["library_scan_dialog"].import_requested.is_connected(Callable(self, "_noop")), "connected library_scan_dialog import_requested")
	_check(managed["library_scan_dialog"].closed.is_connected(Callable(self, "_noop")), "connected library_scan_dialog closed")
	_check(managed["game_manage_menu"].action_requested.is_connected(Callable(self, "_noop")), "connected game_manage_menu action_requested")
	_check(managed["steam_search_dialog"].search_requested.is_connected(Callable(self, "_noop")), "connected steam_search_dialog search_requested")
	_check(managed["steam_search_dialog"].apply_requested.is_connected(Callable(self, "_noop")), "connected steam_search_dialog apply_requested")
	_check(managed["game_metadata_dialog"].save_requested.is_connected(Callable(self, "_noop")), "connected game_metadata_dialog save_requested")
	_check(managed["game_launch_dialog"].save_requested.is_connected(Callable(self, "_noop")), "connected game_launch_dialog save_requested")
	_check(managed["playtime_edit_dialog"].save_requested.is_connected(Callable(self, "_noop")), "connected playtime_edit_dialog save_requested")
	_check(managed["game_remove_confirm"].confirmed.is_connected(Callable(self, "_noop")), "connected game_remove_confirm confirmed")
	var sgdb_dialog = managed["game_scraper_dialog"]
	sgdb_dialog._item_id = "g-context-1"
	sgdb_dialog._selected_sgdb_id = 42
	var grid_section: Dictionary = sgdb_dialog._sections["grid"]
	grid_section["selected_url"] = "https://assets.example/grid.png"
	sgdb_dialog._sections["grid"] = grid_section
	sgdb_dialog._on_apply_pressed()
	_check(str(_sgdb_apply_event.get("item_id", "")) == "g-context-1" and not main_source.contains("_sgdb_target_item_id"), "SGDB apply carries target without main duplicate state")
	_check(int(_sgdb_apply_event.get("sgdb_id", 0)) == 42 and str(_sgdb_apply_event.get("asset_type", "")) == "grid" and str(_sgdb_apply_event.get("url", "")) == "https://assets.example/grid.png", "SGDB apply retains selected asset context")
	if failures == 0 and checks == EXPECTED_CHECKS:
		print("GAME DIALOG ASSEMBLY BUILDER CONTRACT PASS: %d checks" % checks)
		get_tree().quit(0)
	else:
		push_error("GAME DIALOG ASSEMBLY BUILDER CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
