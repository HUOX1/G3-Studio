extends Node

const COORDINATOR_SCRIPT: Script = preload("res://scripts/steam_batch_scrape_coordinator.gd")
var checks: int = 0
var failures: int = 0
var searches: Array[Dictionary] = []
var applies: Array[Dictionary] = []
var finishes: Array[int] = []

func _ready() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("[PASS] ", label)
	else:
		failures += 1
		push_error("[FAIL] " + label)

func _search(gen: int, item: String, title: String, remaining: int) -> void:
	searches.append({"gen": gen, "item": item, "title": title, "remaining": remaining})

func _apply(gen: int, item: String, external_id: int) -> void:
	applies.append({"gen": gen, "item": item, "external_id": external_id})

func _finish(gen: int) -> void:
	finishes.append(gen)

func _run() -> void:
	var coordinator: Node = COORDINATOR_SCRIPT.new()
	add_child(coordinator)
	coordinator.search_requested.connect(_search)
	coordinator.apply_requested.connect(_apply)
	coordinator.finished.connect(_finish)
	_check(not coordinator.is_active(), "starts idle")
	_check(coordinator.generation() == 0, "initial generation zero")
	var empty_gen: int = coordinator.start([])
	_check(empty_gen == 1, "empty batch advances generation")
	_check(finishes == [empty_gen], "empty batch finishes once")
	_check(searches.is_empty(), "empty batch sends no search")
	_check(not coordinator.is_active(), "empty batch not busy")
	coordinator.on_search_result(empty_gen, "ghost", true, [])
	_check(finishes.size() == 1, "late empty batch callback ignored")
	var a: int = coordinator.start([{"id": "a", "title": "Alpha", "english_name": "A EN"}, {"id": "a", "title": "Duplicate"}, {"id": "b", "title": "Beta"}, {}, "invalid"])
	_check(a == 2 and coordinator.is_active(), "nonempty batch starts")
	_check(searches.size() == 1, "first item dispatched once")
	_check(searches[-1].item == "a" and searches[-1].title == "A EN", "english title preferred")
	_check(searches[-1].remaining == 1, "duplicate and invalid IDs skipped")
	_check(coordinator.current_id() == "a" and coordinator.phase() == "search", "current search identity tracked")
	coordinator.on_search_result(a, "wrong", true, [{"external_id": 11}])
	_check(applies.is_empty(), "wrong item response ignored")
	coordinator.on_search_result(a - 1, "a", true, [{"external_id": 11}])
	_check(applies.is_empty(), "stale generation ignored")
	coordinator.on_search_result(a, "a", true, [{"external_id": 44}])
	_check(applies.size() == 1 and applies[-1].external_id == 44, "first search result starts apply")
	_check(applies[-1].item == "a" and applies[-1].gen == a, "apply binds current identity")
	_check(coordinator.phase() == "apply", "awaiting apply response")
	coordinator.on_search_result(a, "a", true, [{"external_id": 99}])
	_check(applies.size() == 1, "duplicate search cannot reapply")
	_check(not coordinator.dispatch_failed(a, "a", "search"), "stale search send failure ignored")
	_check(coordinator.on_apply_result(a, "a"), "apply result accepted once")
	_check(searches.size() == 2 and searches[-1].item == "b", "apply completion advances queue")
	_check(searches[-1].title == "Beta" and searches[-1].remaining == 0, "title fallback and remaining count")
	_check(not coordinator.on_apply_result(a, "a"), "duplicate apply response ignored")
	_check(searches.size() == 2, "duplicate apply does not skip next item")
	coordinator.on_search_result(a, "b", true, [{"external_id": 0}])
	_check(finishes.size() == 2 and finishes[-1] == a, "invalid external ID completes batch")
	_check(not coordinator.is_active() and coordinator.phase() == "idle", "completion clears busy state")
	coordinator.on_search_result(a, "b", false, [])
	_check(finishes.size() == 2, "late callback does not finish twice")
	var b: int = coordinator.start([{"id": "old", "title": "Old"}])
	var c: int = coordinator.start([{"id": "new", "title": "New"}])
	_check(c == b + 1, "restart advances generation")
	_check(coordinator.current_id() == "new", "restart replaces current item")
	coordinator.on_search_result(b, "old", true, [{"external_id": 77}])
	_check(applies.size() == 1, "old batch cannot start apply")
	_check(not coordinator.dispatch_failed(b, "old", "search"), "old batch send failure ignored")
	coordinator.on_search_result(c, "new", false, [])
	_check(finishes[-1] == c, "new batch finishes independently")
	var d: int = coordinator.start([{"id": "fail-search", "title": "One"}, {"id": "fail-apply", "title": "Two"}, {"id": "last", "title": "Three"}])
	_check(coordinator.dispatch_failed(d, "fail-search", "search"), "failed search send advances")
	_check(coordinator.current_id() == "fail-apply", "failed search does not stall")
	coordinator.on_search_result(d, "fail-apply", true, [{"external_id": 5}])
	_check(applies[-1].item == "fail-apply", "next item can request apply")
	_check(not coordinator.dispatch_failed(d, "fail-apply", "search"), "wrong failure phase ignored")
	_check(coordinator.dispatch_failed(d, "fail-apply", "apply"), "failed apply send advances")
	_check(coordinator.current_id() == "last" and coordinator.phase() == "search", "failed apply does not stall")
	coordinator.on_search_result(d, "last", true, [{"bad": "data"}])
	_check(finishes[-1] == d, "missing external ID advances")
	var e: int = coordinator.start([{"id": "cancel", "title": "Cancel"}])
	coordinator.cancel()
	_check(not coordinator.is_active() and coordinator.remaining_count() == 0, "disconnect cancel clears queue")
	_check(coordinator.generation() == e + 1, "cancel invalidates generation")
	coordinator.on_search_result(e, "cancel", true, [{"external_id": 22}])
	_check(applies.size() == 2, "cancelled callback cannot apply")
	_check(finishes[-1] == d, "cancel does not claim success")
	var f: int = coordinator.start([{"id": "recover", "title": "Recover"}])
	_check(f == e + 2 and coordinator.is_active(), "fresh batch after disconnect")
	coordinator.on_search_result(f, "recover", true, [{"external_id": 33}])
	_check(applies[-1].item == "recover", "fresh batch apply request")
	_check(coordinator.on_apply_result(f, "recover"), "fresh batch apply completes")
	_check(finishes[-1] == f and not coordinator.is_active(), "fresh batch finished once")
	# Same-generation late apply must not advance the next item or alter UI ownership.
	var g: int = coordinator.start([{"id": "first", "title": "First"}, {"id": "second", "title": "Second"}])
	coordinator.on_search_result(g, "first", true, [{"external_id": 101}])
	_check(not coordinator.on_apply_result(g, "second"), "wrong item apply rejected")
	_check(coordinator.current_id() == "first" and coordinator.phase() == "apply", "wrong apply retains current item")
	_check(coordinator.on_apply_result(g, "first"), "first item apply accepted")
	coordinator.on_search_result(g, "second", true, [{"external_id": 202}])
	_check(coordinator.current_id() == "second" and coordinator.phase() == "apply", "second item reaches apply phase")
	_check(not coordinator.on_apply_result(g, "first"), "late first apply cannot advance second")
	_check(coordinator.is_active() and coordinator.current_id() == "second", "second item survives stale completion")
	_check(not coordinator.dispatch_failed(g, "first", "apply"), "stale apply send failure cannot advance second")
	_check(coordinator.on_apply_result(g, "second"), "second item completes normally")
	_check(finishes[-1] == g and not coordinator.is_active(), "same-generation batch finishes once")
	_check(not coordinator.on_apply_result(g, "second"), "duplicate final apply ignored")
	# A cancelled generation must not complete a new batch with the same item ID.
	var h: int = coordinator.start([{"id": "repeat", "title": "Old"}])
	coordinator.on_search_result(h, "repeat", true, [{"external_id": 303}])
	var i: int = coordinator.start([{"id": "repeat", "title": "New"}])
	coordinator.on_search_result(i, "repeat", true, [{"external_id": 404}])
	_check(not coordinator.on_apply_result(h, "repeat"), "restarted generation rejects same-ID stale apply")
	_check(coordinator.is_active() and coordinator.phase() == "apply", "new generation remains in apply")
	_check(coordinator.on_apply_result(i, "repeat"), "new generation apply accepted")
	_check(finishes[-1] == i and not coordinator.is_active(), "restarted batch finishes once")
	if failures == 0 and checks == 61:
		print("STEAM BATCH SCRAPE COORDINATOR CONTRACT PASS: 61 checks")
		get_tree().quit(0)
	else:
		push_error("STEAM BATCH SCRAPE COORDINATOR CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
