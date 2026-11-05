extends Node

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
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd").replace("\r\n", "\n")
	_check(source.contains("const STEAM_BATCH_SCRAPE_COORDINATOR_SCRIPT: Script = preload("), "coordinator preloaded")
	_check(source.contains("_steam_batch_scrape_coordinator = STEAM_BATCH_SCRAPE_COORDINATOR_SCRIPT.new()"), "coordinator instantiated")
	_check(source.contains("add_child(_steam_batch_scrape_coordinator)"), "coordinator in scene tree")
	_check(source.contains("search_requested.connect(_on_steam_batch_search_requested)"), "search adapter wired")
	_check(source.contains("apply_requested.connect(_on_steam_batch_apply_requested)"), "apply adapter wired")
	_check(source.contains("finished.connect(_on_steam_batch_finished)"), "finish adapter wired")
	_check(source.contains("_steam_batch_scrape_coordinator.cancel()"), "disconnect cancels batch")
	_check(source.contains("_steam_batch_scrape_coordinator.on_search_result(generation, item_id, ok, data)"), "search responses delegated")
	_check(source.contains("_steam_batch_scrape_coordinator.on_apply_result(generation, item_id)"), "apply responses delegated")
	_check(source.contains("generation != _steam_batch_scrape_coordinator.generation()"), "stale apply responses guarded")
	_check(source.contains("_steam_batch_scrape_coordinator.start(items)"), "UI starts state machine")
	_check(source.contains("request_steam_batch_search(title, item_id, generation)"), "search request uses generation")
	_check(source.contains("request_steam_batch_apply(item_id, external_id, generation)"), "apply request uses generation")
	_check(source.count("_steam_batch_scrape_coordinator.dispatch_failed(generation, item_id, ") == 2, "both failed sends handled")
	_check(source.contains("dispatch_failed(generation, item_id, \"search\")"), "search send failure handled")
	_check(source.contains("dispatch_failed(generation, item_id, \"apply\")"), "apply send failure handled")
	_check(source.contains("func _on_steam_batch_finished(_generation: int) -> void:"), "completion handler exists")
	_check(source.contains("_request_games_list()"), "game list refresh retained")
	_check(not source.contains("_process_next_batch_scrape"), "legacy queue driver removed")
	_check(not source.contains("var _batch_scrape_queue:"), "legacy queue state removed")
	_check(not source.contains("var _is_batch_scraping:"), "legacy busy state removed")
	_check(not source.contains("var _batch_scrape_generation:"), "legacy generation removed")
	_check(source.contains("item_id != _steam_batch_scrape_coordinator.current_id()"), "apply UI guarded by item identity")
	var controller_source: String = FileAccess.get_file_as_string("res://scripts/game_controller.gd").replace("\r\n", "\n")
	_check(controller_source.contains("steam_batch_apply_completed(generation: int, item_id: String"), "apply signal carries item identity")
	_check(controller_source.contains('bind(generation, item_id)'), "apply route binds target item")
	_check(source.contains("game_section.resolve_games_by_ids(item_ids)"), "main delegates selected game resolution")
	_check(source.contains("game_section.toggle_batch_mode(not game_section.is_batch_mode())"), "batch toggle uses public state query")
	_check(not source.contains("game_section._batch_mode"), "main no longer reads batch mode internals")
	_check(not source.contains("game_section._all_games"), "main no longer reads game snapshot internals")
	var game_section_source: String = FileAccess.get_file_as_string("res://scripts/game_section.gd").replace("\r\n", "\n")
	_check(game_section_source.contains("func resolve_games_by_ids(item_ids: Array) -> Array[Dictionary]:"), "game section owns snapshot ID resolver")
	_check(game_section_source.contains("func is_batch_mode() -> bool:\n\treturn _batch_mode"), "game section exposes read-only batch mode query")
	var section_instance: G3GameSection = load("res://scripts/game_section.gd").new()
	_check(not section_instance.is_batch_mode(), "batch mode query starts disabled")
	var snapshot: Array[Dictionary] = [{"id": "g1", "title": "One"}, {"id": "g2", "title": "Two"}]
	section_instance._all_games = snapshot
	var resolved: Array[Dictionary] = section_instance.resolve_games_by_ids(["g2", "missing", "g1", "g2"])
	_check(resolved.size() == 3 and str(resolved[0].get("id", "")) == "g2" and str(resolved[1].get("id", "")) == "g1", "resolver preserves request order and ignores missing IDs")
	_check(str(resolved[0].get("id", "")) == str(resolved[2].get("id", "")), "resolver preserves duplicate requested IDs")
	section_instance.free()
	if failures == 0 and checks == 34:
		print("STEAM BATCH SCRAPE MAIN INTEGRATION CONTRACT PASS: 34 checks")
		get_tree().quit(0)
	else:
		push_error("STEAM BATCH SCRAPE MAIN INTEGRATION CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
