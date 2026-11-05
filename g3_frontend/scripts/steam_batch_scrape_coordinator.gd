extends Node

# Stage 7.1: pure sequential Steam batch scrape state machine.
# No socket, GameController, game_section or UI references.
# The adapter must report an empty request ID via dispatch_failed() in Stage 7.2.
signal search_requested(generation: int, item_id: String, title: String, remaining: int)
signal apply_requested(generation: int, item_id: String, external_id: int)
signal finished(generation: int)

var _generation: int = 0
var _queue: Array[Dictionary] = []
var _active: bool = false
var _phase: String = "idle"
var _current_id: String = ""

func generation() -> int:
	return _generation

func is_active() -> bool:
	return _active

func phase() -> String:
	return _phase

func current_id() -> String:
	return _current_id

func remaining_count() -> int:
	return _queue.size()

func start(items: Array) -> int:
	# A new batch invalidates every callback from an older generation.
	_generation += 1
	_queue.clear()
	_current_id = ""
	_phase = "idle"
	_active = true
	var seen: Dictionary = {}
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		var item_id: String = str(item.get("id", ""))
		if item_id.is_empty() or seen.has(item_id):
			continue
		seen[item_id] = true
		_queue.append(item.duplicate(true))
	_advance()
	return _generation

func cancel() -> void:
	# Disconnect or explicit cancel: do not report a successful completion.
	_generation += 1
	_queue.clear()
	_current_id = ""
	_phase = "idle"
	_active = false

func on_search_result(generation_id: int, item_id: String, ok: bool, data: Variant) -> void:
	if not _matches(generation_id, item_id, "search"):
		return
	if ok and data is Array and not (data as Array).is_empty():
		var first: Variant = (data as Array)[0]
		if first is Dictionary:
			var external_id: int = int((first as Dictionary).get("external_id", 0))
			if external_id > 0:
				_phase = "apply"
				apply_requested.emit(_generation, _current_id, external_id)
				return
	_advance()

func on_apply_result(generation_id: int, item_id: String) -> bool:
	# A generation can contain multiple applies: a late result from item A
	# must never advance item B, even if B is also in apply phase.
	if not _matches(generation_id, item_id, "apply"):
		return false
	_advance()
	return true

func dispatch_failed(generation_id: int, item_id: String, step: String) -> bool:
	# Called synchronously by the UI adapter when a request returns empty ID.
	if not _matches(generation_id, item_id, step):
		return false
	_advance()
	return true

func _matches(generation_id: int, item_id: String, step: String) -> bool:
	return _active and generation_id == _generation and _current_id == item_id and _phase == step

func _advance() -> void:
	if not _active:
		return
	if _queue.is_empty():
		_active = false
		_phase = "idle"
		_current_id = ""
		finished.emit(_generation)
		return
	var item: Dictionary = _queue.pop_front()
	_current_id = str(item.get("id", ""))
	var title: String = str(item.get("english_name", ""))
	if title.is_empty():
		title = str(item.get("title", ""))
	_phase = "search"
	search_requested.emit(_generation, _current_id, title, _queue.size())
