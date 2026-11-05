extends SceneTree

const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")

class MockBackend:
	extends Node
	signal response_received(request_id: String, ok: bool, data: Variant, error: Variant)
	signal event_received(event_type: String, payload: Dictionary)
	signal disconnected(code: int, reason: String)

	var request_counter: int = 0
	var available: bool = true

	func request(_command_type: String, _payload: Dictionary = {}) -> String:
		if not available:
			return ""
		request_counter += 1
		return "g%06d" % request_counter

	func emit_response(request_id: String, ok: bool = true, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(request_id, ok, data, error)

	func emit_event(event_type: String, payload: Dictionary = {}) -> void:
		event_received.emit(event_type, payload)

	func drop_connection() -> void:
		available = false
		disconnected.emit(1006, "test disconnect")

func _initialize() -> void:
	call_deferred("_run")

var _checks: int = 0
var _failures: int = 0
var _routed_count: int = 0
var _legacy_count: int = 0
var _legacy_event_count: int = 0
var _last_routed_id: String = ""
var _last_routed_ok: bool = false
var _last_routed_data: Variant = null
var _last_routed_error: Variant = null
var _last_legacy_id: String = ""
var _latest_callback_count: int = 0
var _latest_callback_id: String = ""

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("BACKEND ROUTER CHECK FAILED: " + description)

func _on_routed_response(request_id: String, ok: bool, data: Variant, error: Variant) -> void:
	_routed_count += 1
	_last_routed_id = request_id
	_last_routed_ok = ok
	_last_routed_data = data
	_last_routed_error = error

func _on_legacy_response(request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy_count += 1
	_last_legacy_id = request_id

func _on_legacy_event(_event_type: String, _payload: Dictionary) -> void:
	_legacy_event_count += 1

func _on_latest_response(request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_latest_callback_count += 1
	_latest_callback_id = request_id

func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	root.add_child(backend)
	var router: Variant = ROUTER_SCRIPT.new()
	root.add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy_response)
	router.legacy_event_received.connect(_on_legacy_event)

	# Empty and handshake IDs must not enter application response handling.
	backend.emit_response("")
	backend.emit_response("hello-000001")
	_check(_legacy_count == 0, "empty and handshake responses are ignored")

	# A migrated read-only request is consumed by its registered callback once.
	var request_id: String = router.request("app.info", {}, Callable(self, "_on_routed_response"))
	_check(not request_id.is_empty(), "router returns the backend request ID")
	_check(router.pending_route_count() == 1, "route is registered after successful send")
	var info: Dictionary = {"display": "test-version"}
	backend.emit_response(request_id, true, info, null)
	_check(_routed_count == 1, "registered response invokes the callback once")
	_check(_last_routed_id == request_id and _last_routed_ok, "callback receives ID and status")
	_check(_last_routed_data == info and _last_routed_error == null, "callback receives response payload")
	_check(router.pending_route_count() == 0, "completed route is removed")
	backend.emit_response(request_id, true, info, null)
	_check(_routed_count == 1 and _legacy_count == 0, "duplicate routed response has no side effects")

	var failed_response_id: String = router.request("app.info", {}, Callable(self, "_on_routed_response"))
	backend.emit_response(failed_response_id, false, null, {"message": "test failure"})
	_check(_routed_count == 2 and not _last_routed_ok, "failed response reaches the registered callback")
	_check(_last_routed_error == {"message": "test failure"}, "error payload is preserved")

	# Independent read-only requests may complete out of order without cross-routing.
	var concurrent_a: String = router.request("fontsets.list", {}, Callable(self, "_on_routed_response"))
	var concurrent_b: String = router.request("fonts.list", {}, Callable(self, "_on_routed_response"))
	backend.emit_response(concurrent_b, true, ["fonts"], null)
	_check(_routed_count == 3 and _last_routed_id == concurrent_b, "out-of-order response B routes to B callback")
	backend.emit_response(concurrent_a, true, ["fontsets"], null)
	_check(_routed_count == 4 and _last_routed_id == concurrent_a, "out-of-order response A routes to A callback")
	_check(router.pending_route_count() == 0, "concurrent routes are both consumed")

	# A logical single-slot request must invalidate its predecessor, matching
	# the old _pending_*_id assignment semantics in main.gd.
	var latest_old_id: String = router.request_latest(
		"settings.get", "settings.get", {}, Callable(self, "_on_latest_response")
	)
	var latest_new_id: String = router.request_latest(
		"settings.get", "settings.get", {}, Callable(self, "_on_latest_response")
	)
	_check(not latest_old_id.is_empty() and not latest_new_id.is_empty(), "latest-slot requests are sent")
	_check(router.pending_route_count() == 1, "new latest-slot request replaces old route")
	backend.emit_response(latest_old_id, true, {"settings": "stale"}, null)
	_check(_latest_callback_count == 0, "superseded response is ignored")
	backend.emit_response(latest_new_id, true, {"settings": "current"}, null)
	_check(_latest_callback_count == 1 and _latest_callback_id == latest_new_id, "only newest response is consumed")
	_check(router.pending_route_count() == 0, "latest slot clears after response")
	var latest_pending_id: String = router.request_latest(
		"settings.get", "settings.get", {}, Callable(self, "_on_latest_response")
	)
	backend.available = false
	var failed_latest_id: String = router.request_latest(
		"settings.get", "settings.get", {}, Callable(self, "_on_latest_response")
	)
	_check(failed_latest_id.is_empty(), "failed latest-slot replacement returns empty ID")
	_check(router.pending_route_count() == 0, "failed replacement leaves no active route")
	backend.available = true
	backend.emit_response(latest_pending_id, true, {"settings": "stale-after-failure"}, null)
	_check(_latest_callback_count == 1, "failed replacement still invalidates the previous response")

	# Requests not migrated yet retain the original main.gd fallback path.
	backend.emit_response("g999999", true, {"legacy": true}, null)
	_check(_legacy_count == 1 and _last_legacy_id == "g999999", "unknown response falls back to legacy handler")

	# Failed sends must not leave a route registered.
	backend.available = false
	var failed_id: String = router.request("app.info", {}, Callable(self, "_on_routed_response"))
	_check(failed_id.is_empty(), "failed request returns an empty ID")
	_check(router.pending_route_count() == 0, "failed request does not register a route")

	# Disconnect invalidates pending routes; late replies must not fall back.
	backend.available = true
	var stale_id: String = router.request("app.info", {}, Callable(self, "_on_routed_response"))
	backend.drop_connection()
	_check(router.pending_route_count() == 0, "disconnect clears active routes")
	backend.emit_response(stale_id, true, info, null)
	_check(_routed_count == 4 and _legacy_count == 1, "late response after disconnect is ignored")

	# Events retain a single router ingress and one legacy delivery.
	backend.emit_event("library.changed", {"media_type": "game"})
	_check(_legacy_event_count == 1, "backend event is forwarded once")

	if _failures == 0:
		print("BACKEND ROUTER CONTRACT PASS: %d checks" % _checks)
	else:
		push_error("BACKEND ROUTER CONTRACT FAIL: %d/%d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)
