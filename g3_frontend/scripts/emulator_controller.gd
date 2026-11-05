extends Node

# Stage 5.7: emulator read requests only. The configuration page and the
# manual game-create dialog must retain independent latest-wins slots.
signal list_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal game_create_list_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal save_completed(request_id: String, ok: bool, data: Variant, error: Variant)
signal delete_completed(request_id: String, ok: bool, data: Variant, error: Variant)

var _router: Node = null

func configure(router: Node) -> void:
	_router = router

func request_list() -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"emulators.list", "emulators.list", {},
		Callable(self, "_on_list_response")
	)

func request_game_create_list() -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"emulators.for_game_create", "emulators.list", {},
		Callable(self, "_on_game_create_list_response")
	)

# Save and delete are separate latest-wins operations, as in main.gd before
# migration. Keep the original payload and use the router's stale-reply guard.
func request_save(payload: Dictionary) -> String:
	if _router == null:
		return ""
	return _router.request_latest(
		"emulators.save", "emulators.save", payload,
		Callable(self, "_on_save_response")
	)

func request_delete(emulator_id: String) -> String:
	if _router == null or emulator_id.is_empty():
		return ""
	return _router.request_latest(
		"emulators.delete", "emulators.delete", {"id": emulator_id},
		Callable(self, "_on_delete_response")
	)

func _on_save_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	save_completed.emit(request_id, ok, data, error)

func _on_delete_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	delete_completed.emit(request_id, ok, data, error)

func _on_list_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	list_completed.emit(request_id, ok, data, error)

func _on_game_create_list_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	game_create_list_completed.emit(request_id, ok, data, error)
