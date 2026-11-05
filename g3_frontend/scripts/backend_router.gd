extends Node

# UI-M6: Shared formatting for backend error payloads.
static func format_error_message(error: Variant) -> String:
	if error is Dictionary:
		var payload: Dictionary = error as Dictionary
		return str(payload.get("message", payload))
	return str(error)

signal legacy_response_received(request_id: String, ok: bool, data: Variant, error: Variant)
signal legacy_event_received(event_type: String, payload: Dictionary)

# Routes are registered only for requests explicitly migrated to the router.
# Everything else follows the legacy response path until its business slice moves.
var _backend: Variant = null
var _routes: Dictionary = {}
var _retired_ids: Dictionary = {}
var _latest_slots: Dictionary = {}
var _connection_generation: int = 0

func attach(backend: Node) -> void:
	if _backend != null:
		return
	_backend = backend
	if not _backend.response_received.is_connected(_on_backend_response):
		_backend.response_received.connect(_on_backend_response)
	if not _backend.event_received.is_connected(_on_backend_event):
		_backend.event_received.connect(_on_backend_event)
	if not _backend.disconnected.is_connected(_on_backend_disconnected):
		_backend.disconnected.connect(_on_backend_disconnected)

func request(command_type: String, payload: Dictionary, callback: Callable) -> String:
	if _backend == null or not callback.is_valid():
		return ""
	var request_id: String = str(_backend.request(command_type, payload))
	if request_id.is_empty():
		return ""
	_routes[request_id] = {
		"callback": callback,
		"command": command_type,
		"generation": _connection_generation,
	}
	return request_id

# Preserve the legacy single-pending-slot behavior for requests where a newer
# request supersedes the older one (for example settings.get).
func request_latest(slot_key: String, command_type: String, payload: Dictionary, callback: Callable) -> String:
	if slot_key.is_empty():
		return ""
	if _latest_slots.has(slot_key):
		var previous_id: String = str(_latest_slots[slot_key])
		_routes.erase(previous_id)
		_retired_ids[previous_id] = true
		_latest_slots.erase(slot_key)
	var request_id: String = request(command_type, payload, callback)
	if not request_id.is_empty():
		_latest_slots[slot_key] = request_id
		var route: Dictionary = _routes[request_id]
		route["slot_key"] = slot_key
		_routes[request_id] = route
	return request_id

func pending_route_count() -> int:
	return _routes.size()

func _on_backend_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	# Empty IDs and handshake replies are not application business responses.
	if request_id.is_empty() or request_id.begins_with("hello-"):
		return
	if _retired_ids.has(request_id):
		return
	if _routes.has(request_id):
		var route: Dictionary = _routes[request_id]
		_routes.erase(request_id)
		_retired_ids[request_id] = true
		var slot_key: String = str(route.get("slot_key", ""))
		if not slot_key.is_empty() and str(_latest_slots.get(slot_key, "")) == request_id:
			_latest_slots.erase(slot_key)
		if int(route.get("generation", -1)) != _connection_generation:
			return
		var callback: Callable = route.get("callback", Callable())
		if callback.is_valid():
			callback.call(request_id, ok, data, error)
		return
	# During incremental migration, unregistered requests remain owned by main.gd.
	legacy_response_received.emit(request_id, ok, data, error)

func _on_backend_event(event_type: String, payload: Dictionary) -> void:
	legacy_event_received.emit(event_type, payload)

func _on_backend_disconnected(_code: int, _reason: String) -> void:
	_connection_generation += 1
	for request_id: Variant in _routes.keys():
		_retired_ids[str(request_id)] = true
	_routes.clear()
	_latest_slots.clear()
