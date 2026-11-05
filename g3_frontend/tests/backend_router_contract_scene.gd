extends Node

# Standalone F6 scene runner. It does not start the G3 main scene or backend.
const ROUTER_SCRIPT: Script = preload("res://scripts/backend_router.gd")

class MockBackend:
	extends Node
	signal response_received(request_id: String, ok: bool, data: Variant, error: Variant)
	signal event_received(event_type: String, payload: Dictionary)
	signal disconnected(code: int, reason: String)

	var request_counter: int = 0
	var available: bool = true

	func request(_command: String, _payload: Dictionary = {}) -> String:
		if not available:
			return ""
		request_counter += 1
		return "test-%06d" % request_counter

	func reply(request_id: String, ok: bool = true, data: Variant = null, error: Variant = null) -> void:
		response_received.emit(request_id, ok, data, error)

	func disconnect_backend() -> void:
		available = false
		disconnected.emit(1006, "test disconnect")

var _checks: int = 0
var _failures: int = 0
var _fontset_calls: int = 0
var _font_calls: int = 0
var _legacy_calls: int = 0
var _event_calls: int = 0
var _fontset_id: String = ""
var _font_id: String = ""
var _fontset_data: Variant = null
var _font_data: Variant = null
var _latest_calls: int = 0
var _latest_id: String = ""

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] ", message)
	else:
		_failures += 1
		push_error("[FAIL] " + message)

func _on_fontsets(request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	_fontset_calls += 1
	_fontset_id = request_id
	_fontset_data = data if ok else null

func _on_fonts(request_id: String, ok: bool, data: Variant, _error: Variant) -> void:
	_font_calls += 1
	_font_id = request_id
	_font_data = data if ok else null

func _on_latest(request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_latest_calls += 1
	_latest_id = request_id

func _on_legacy(_request_id: String, _ok: bool, _data: Variant, _error: Variant) -> void:
	_legacy_calls += 1

func _on_event(_event_type: String, _payload: Dictionary) -> void:
	_event_calls += 1

func _run() -> void:
	var backend: MockBackend = MockBackend.new()
	add_child(backend)
	var router: Variant = ROUTER_SCRIPT.new()
	add_child(router)
	router.attach(backend)
	router.legacy_response_received.connect(_on_legacy)
	router.legacy_event_received.connect(_on_event)

	# Separate callbacks are essential: the two requests must never cross-route.
	var fontsets_id: String = router.request("fontsets.list", {}, Callable(self, "_on_fontsets"))
	var fonts_id: String = router.request("fonts.list", {}, Callable(self, "_on_fonts"))
	_check(not fontsets_id.is_empty() and not fonts_id.is_empty() and fontsets_id != fonts_id, "distinct request IDs")
	_check(router.pending_route_count() == 2, "both requests registered")

	# Reply in the reverse order: fonts first, fontsets second.
	var fonts_payload: Array = [{"family": "MockFont"}]
	var fontsets_payload: Array = [{"id": "mock_fontset", "active": true}]
	backend.reply(fonts_id, true, fonts_payload, null)
	_check(_font_calls == 1 and _fontset_calls == 0, "fonts response invokes only fonts callback")
	_check(_font_id == fonts_id and _font_data == fonts_payload, "fonts callback receives its own payload")
	_check(router.pending_route_count() == 1, "fonts route consumed once")

	backend.reply(fontsets_id, true, fontsets_payload, null)
	_check(_fontset_calls == 1 and _font_calls == 1, "fontsets response invokes only fontsets callback")
	_check(_fontset_id == fontsets_id and _fontset_data == fontsets_payload, "fontsets callback receives its own payload")
	_check(router.pending_route_count() == 0, "both routes consumed")
	_check(_legacy_calls == 0, "routed replies never reach legacy handler")

	backend.reply(fonts_id, true, fonts_payload, null)
	backend.reply(fontsets_id, true, fontsets_payload, null)
	_check(_fontset_calls == 1 and _font_calls == 1 and _legacy_calls == 0, "duplicate replies have no side effects")

	backend.reply("", true, null, null)
	backend.reply("hello-000001", true, null, null)
	_check(_legacy_calls == 0, "empty and handshake IDs ignored")

	# Stage 1.4: latest-slot requests preserve the old single pending ID behavior.
	# A superseded response must not reach the callback or the legacy handler.
	var latest_old_id: String = router.request_latest("settings.get", "settings.get", {}, Callable(self, "_on_latest"))
	var latest_new_id: String = router.request_latest("settings.get", "settings.get", {}, Callable(self, "_on_latest"))
	_check(not latest_old_id.is_empty() and not latest_new_id.is_empty() and latest_old_id != latest_new_id, "latest-slot requests have distinct IDs")
	_check(router.pending_route_count() == 1, "new latest-slot request replaces the old route")
	backend.reply(latest_old_id, true, {"settings": "old"}, null)
	_check(_latest_calls == 0 and _legacy_calls == 0, "superseded response is ignored")
	backend.reply(latest_new_id, true, {"settings": "new"}, null)
	_check(_latest_calls == 1 and _latest_id == latest_new_id, "newest response reaches its callback once")
	_check(router.pending_route_count() == 0, "latest slot clears after successful response")
	backend.reply(latest_new_id, true, {"settings": "duplicate"}, null)
	_check(_latest_calls == 1 and _legacy_calls == 0, "duplicate latest response is ignored")

	var latest_pending_id: String = router.request_latest("settings.get", "settings.get", {}, Callable(self, "_on_latest"))
	_check(not latest_pending_id.is_empty() and router.pending_route_count() == 1, "latest slot registers pending request")
	backend.available = false
	var failed_latest_id: String = router.request_latest("settings.get", "settings.get", {}, Callable(self, "_on_latest"))
	_check(failed_latest_id.is_empty(), "failed latest-slot replacement returns empty ID")
	_check(router.pending_route_count() == 0, "failed replacement clears the previous route")
	backend.available = true
	backend.reply(latest_pending_id, true, {"settings": "stale"}, null)
	_check(_latest_calls == 1 and _legacy_calls == 0, "failed replacement still invalidates old response")

	backend.reply("unmigrated-123", true, null, null)
	_check(_legacy_calls == 1, "unmigrated request uses legacy fallback")

	backend.event_received.emit("library.changed", {"media_type": "game"})
	_check(_event_calls == 1, "event forwarded exactly once")

	var stale_id: String = router.request("fontsets.list", {}, Callable(self, "_on_fontsets"))
	_check(router.pending_route_count() == 1, "pending route exists before disconnect")
	backend.disconnect_backend()
	_check(router.pending_route_count() == 0, "disconnect invalidates routes")
	backend.reply(stale_id, true, fontsets_payload, null)
	_check(_fontset_calls == 1 and _legacy_calls == 1, "late response after disconnect ignored")

	var failed_id: String = router.request("fonts.list", {}, Callable(self, "_on_fonts"))
	_check(failed_id.is_empty() and router.pending_route_count() == 0, "failed send does not register a route")

	if _failures == 0:
		print("BACKEND ROUTER SCENE CONTRACT PASS: %d checks" % _checks)
	else:
		push_error("BACKEND ROUTER SCENE CONTRACT FAIL: %d/%d checks failed" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
