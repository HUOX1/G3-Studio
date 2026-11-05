extends Node

signal palette_changed(item_id: String, palette: Dictionary)
signal theme_cleared

var _router: Node = null
var _active_item_id: String = ""
var _generation: int = 0

func configure(router: Node) -> void:
	_router = router

func _theme_diag(message: String) -> void:
	if OS.get_environment("G3_THEME_DIAG") == "1":
		print("[G3_THEME_DIAG] " + message)

func activate_game(item_id: String) -> void:
	var normalized_id: String = item_id.strip_edges()
	if normalized_id.is_empty():
		clear_active_theme()
		return
	_theme_diag("request item=" + normalized_id)
	_active_item_id = normalized_id
	_generation += 1
	var request_generation: int = _generation
	if _router == null:
		_active_item_id = ""
		theme_cleared.emit()
		return
	var request_id: String = _router.request_latest(
		"game.theme.active_palette",
		"game.theme.palette",
		{"id": normalized_id},
		Callable(self, "_on_palette_response").bind(normalized_id, request_generation)
	)
	if request_id.is_empty():
		_active_item_id = ""
		_generation += 1
		theme_cleared.emit()

func clear_active_theme() -> void:
	_generation += 1
	_active_item_id = ""
	theme_cleared.emit()

func get_active_item_id() -> String:
	return _active_item_id

func _on_palette_response(
	_request_id: String,
	ok: bool,
	data: Variant,
	_error: Variant,
	item_id: String,
	request_generation: int
) -> void:
	# A response from a closed detail view or a previous game must never repaint the current UI.
	if request_generation != _generation or item_id != _active_item_id:
		_theme_diag("stale response ignored item=" + item_id)
		return
	if not ok or not (data is Dictionary):
		_active_item_id = ""
		_generation += 1
		theme_cleared.emit()
		return
	var response: Dictionary = data as Dictionary
	if str(response.get("item_id", item_id)) != item_id:
		return
	var palette_value: Variant = response.get("palette", {})
	if not (palette_value is Dictionary):
		_active_item_id = ""
		_generation += 1
		theme_cleared.emit()
		return
	var palette: Dictionary = (palette_value as Dictionary).duplicate(true)
	# Low-chroma/missing covers deliberately retain the app's neutral palette.
	if str(palette.get("status", "ready")) != "ready":
		_active_item_id = ""
		_generation += 1
		theme_cleared.emit()
		return
	_theme_diag("received item=" + item_id + " source=" + str(response.get("source", palette.get("source", ""))) + " colors=" + str(palette.get("colors", {})))
	palette_changed.emit(item_id, palette)
