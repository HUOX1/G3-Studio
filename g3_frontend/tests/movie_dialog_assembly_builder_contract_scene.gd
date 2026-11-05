extends Node

const BUILDER: Script = preload("res://scripts/movie_dialog_assembly_builder.gd")
const EXPECTED_CHECKS: int = 50
var checks: int = 0
var failures: int = 0
var _tmdb_apply_event: Dictionary = {}

func _ready() -> void:
    call_deferred("_run")

func _noop(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
    pass

func _on_tmdb_apply_context(item_id: String, tmdb_id: int, media_type: String) -> void:
    _tmdb_apply_event = {"item_id": item_id, "tmdb_id": tmdb_id, "media_type": media_type}

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
    var callbacks: Dictionary = {}
    callbacks["_on_movie_manage_action_requested"] = Callable(self, "_noop")
    callbacks["_on_movie_blank_action_requested"] = Callable(self, "_noop")
    callbacks["_on_game_blank_action_requested"] = Callable(self, "_noop")
    callbacks["_on_movie_remove_confirmed"] = Callable(self, "_noop")
    callbacks["_on_movie_cover_file_selected"] = Callable(self, "_noop")
    callbacks["_on_movie_metadata_save_requested"] = Callable(self, "_noop")
    callbacks["_on_movie_backdrop_file_selected"] = Callable(self, "_noop")
    callbacks["_on_movie_episode_clicked"] = Callable(self, "_noop")
    callbacks["_on_tmdb_search_requested"] = Callable(self, "_noop")
    callbacks["_on_tmdb_apply_requested"] = Callable(self, "_on_tmdb_apply_context")
    callbacks["_on_poster_list_requested"] = Callable(self, "_noop")
    callbacks["_on_poster_thumb_requested"] = Callable(self, "_noop")
    callbacks["_on_poster_apply_requested"] = Callable(self, "_noop")
    var nodes: Dictionary = BUILDER.new().build(self, ui, callbacks)
    var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    _check(nodes.size() == 10, "ten stable references")
    _check(nodes.has("movie_manage_menu") and nodes["movie_manage_menu"] != null, "returned movie_manage_menu")
    _check(nodes.has("movie_blank_menu") and nodes["movie_blank_menu"] != null, "returned movie_blank_menu")
    _check(nodes.has("game_blank_menu") and nodes["game_blank_menu"] != null, "returned game_blank_menu")
    _check(nodes.has("movie_remove_confirm") and nodes["movie_remove_confirm"] != null, "returned movie_remove_confirm")
    _check(nodes.has("movie_cover_file_dialog") and nodes["movie_cover_file_dialog"] != null, "returned movie_cover_file_dialog")
    _check(nodes.has("movie_metadata_dialog") and nodes["movie_metadata_dialog"] != null, "returned movie_metadata_dialog")
    _check(nodes.has("movie_backdrop_file_dialog") and nodes["movie_backdrop_file_dialog"] != null, "returned movie_backdrop_file_dialog")
    _check(nodes.has("movie_episode_drawer") and nodes["movie_episode_drawer"] != null, "returned movie_episode_drawer")
    _check(nodes.has("tmdb_dialog") and nodes["tmdb_dialog"] != null, "returned tmdb_dialog")
    _check(nodes.has("tmdb_poster_dialog") and nodes["tmdb_poster_dialog"] != null, "returned tmdb_poster_dialog")
    _check(nodes["movie_manage_menu"].get_parent() == ui, "parent movie_manage_menu")
    _check(nodes["movie_blank_menu"].get_parent() == ui, "parent movie_blank_menu")
    _check(nodes["game_blank_menu"].get_parent() == ui, "parent game_blank_menu")
    _check(nodes["movie_remove_confirm"].get_parent() == self, "parent movie_remove_confirm")
    _check(nodes["movie_cover_file_dialog"].get_parent() == ui, "parent movie_cover_file_dialog")
    _check(nodes["movie_metadata_dialog"].get_parent() == self, "parent movie_metadata_dialog")
    _check(nodes["movie_backdrop_file_dialog"].get_parent() == ui, "parent movie_backdrop_file_dialog")
    _check(nodes["movie_episode_drawer"].get_parent() == ui, "parent movie_episode_drawer")
    _check(nodes["tmdb_dialog"].get_parent() == self, "parent tmdb_dialog")
    _check(nodes["tmdb_poster_dialog"].get_parent() == self, "parent tmdb_poster_dialog")
    _check(nodes["movie_cover_file_dialog"].file_mode == FileDialog.FILE_MODE_OPEN_FILE, "cover file mode")
    _check(nodes["movie_backdrop_file_dialog"].file_mode == FileDialog.FILE_MODE_OPEN_FILE, "backdrop file mode")
    _check(nodes["movie_cover_file_dialog"].size == Vector2i(920, 620), "cover picker dimensions")
    _check(nodes["movie_backdrop_file_dialog"].size == Vector2i(920, 620), "backdrop picker dimensions")
    _check(nodes["movie_remove_confirm"].title == "移除电影档案", "remove confirm title")
    _check(ui.get_child(0) == nodes["movie_manage_menu"], "menu order 1")
    _check(ui.get_child(1) == nodes["movie_blank_menu"], "menu order 2")
    _check(ui.get_child(2) == nodes["game_blank_menu"], "menu order 3")
    _check(ui.get_child(3) == nodes["movie_cover_file_dialog"], "ui child order cover")
    _check(ui.get_child(4) == nodes["movie_backdrop_file_dialog"], "ui child order backdrop")
    _check(ui.get_child(5) == nodes["movie_episode_drawer"], "ui child order drawer")
    _check(main_source.contains("MOVIE_DIALOG_ASSEMBLY_BUILDER_SCRIPT.new().build(self, ui, {"), "main delegates movie dialog assembly")
    _check(not main_source.contains("movie_manage_menu = MOVIE_MANAGE_MENU_SCRIPT.new()"), "old inline menu assembly removed")
    _check(not main_source.contains("tmdb_poster_dialog = TMDB_POSTER_DIALOG_SCRIPT.new()"), "old inline TMDB assembly removed")
    _check(nodes["movie_manage_menu"].action_requested.is_connected(Callable(self, "_noop")), "signal 1 connected")
    _check(nodes["movie_blank_menu"].action_requested.is_connected(Callable(self, "_noop")), "signal 2 connected")
    _check(nodes["game_blank_menu"].action_requested.is_connected(Callable(self, "_noop")), "signal 3 connected")
    _check(nodes["movie_remove_confirm"].confirmed.is_connected(Callable(self, "_noop")), "signal 4 connected")
    _check(nodes["movie_cover_file_dialog"].file_selected.is_connected(Callable(self, "_noop")), "signal 5 connected")
    _check(nodes["movie_metadata_dialog"].save_requested.is_connected(Callable(self, "_noop")), "signal 6 connected")
    _check(nodes["movie_backdrop_file_dialog"].file_selected.is_connected(Callable(self, "_noop")), "signal 7 connected")
    _check(nodes["movie_episode_drawer"].episode_clicked.is_connected(Callable(self, "_noop")), "signal 8 connected")
    _check(nodes["tmdb_dialog"].search_requested.is_connected(Callable(self, "_noop")), "signal 9 connected")
    _check(nodes["tmdb_dialog"].apply_requested.is_connected(Callable(self, "_on_tmdb_apply_context")), "signal 10 connected")
    _check(nodes["tmdb_poster_dialog"].poster_list_requested.is_connected(Callable(self, "_noop")), "signal 11 connected")
    _check(nodes["tmdb_poster_dialog"].thumb_requested.is_connected(Callable(self, "_noop")), "signal 12 connected")
    _check(nodes["tmdb_poster_dialog"].poster_apply_requested.is_connected(Callable(self, "_noop")), "signal 13 connected")
    var tmdb_dialog = nodes["tmdb_dialog"]
    tmdb_dialog._item_id = "movie-context-1"
    tmdb_dialog._selected_tmdb_id = 550
    tmdb_dialog._selected_media_type = "tv"
    tmdb_dialog._on_apply_pressed()
    _check(str(_tmdb_apply_event.get("item_id", "")) == "movie-context-1" and not main_source.contains("_tmdb_target_item_id"), "TMDB apply carries target without main duplicate state")
    _check(int(_tmdb_apply_event.get("tmdb_id", 0)) == 550 and str(_tmdb_apply_event.get("media_type", "")) == "tv", "TMDB apply retains selected result context")
    if failures == 0 and checks == EXPECTED_CHECKS:
        print("MOVIE DIALOG ASSEMBLY BUILDER CONTRACT PASS: %d checks" % checks)
        get_tree().quit(0)
    else:
        push_error("MOVIE DIALOG ASSEMBLY BUILDER CONTRACT FAIL: %d/%d" % [failures, checks])
        get_tree().quit(1)
