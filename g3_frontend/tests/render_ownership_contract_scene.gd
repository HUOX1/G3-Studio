extends Node

const COORDINATOR_SCRIPT: Script = preload("res://scripts/render_ownership_coordinator.gd")
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
	var coordinator: Node = COORDINATOR_SCRIPT.new()
	add_child(coordinator)
	_check(not coordinator.has_owners(), "starts without owners")
	_check(coordinator.owner_count() == 0, "initial owner count zero")
	var initial_token: int = coordinator.pause_token()
	_check(not coordinator.should_pause_for_token(initial_token), "no idle pause")
	_check(not coordinator.claim("movie", ""), "empty movie session rejected")
	_check(not coordinator.claim("other", "x"), "unknown kind rejected")
	_check(not coordinator.claim("game", ""), "empty game session rejected")
	_check(coordinator.pause_token() == initial_token, "invalid claims do not advance generation")
	_check(coordinator.claim("movie", "a"), "confirmed movie claimed")
	_check(coordinator.has_owners(), "movie owner requires pause")
	_check(coordinator.owns("movie", "a"), "movie owner tracked")
	_check(not coordinator.should_pause_for_token(initial_token), "stale initial token invalid")
	var movie_token: int = coordinator.pause_token()
	_check(coordinator.should_pause_for_token(movie_token), "current movie token valid")
	_check(not coordinator.claim("movie", "a"), "duplicate claim ignored")
	_check(coordinator.pause_token() == movie_token, "duplicate claim does not invalidate timer")
	_check(coordinator.claim("game", "b"), "game can overlap movie")
	_check(coordinator.owner_count() == 2, "mixed owners counted")
	_check(not coordinator.should_pause_for_token(movie_token), "new game invalidates prior timer")
	var mixed_token: int = coordinator.pause_token()
	_check(coordinator.should_pause_for_token(mixed_token), "new token valid for mixed owners")
	_check(not coordinator.release("game", "old"), "stale game exit ignored")
	_check(not coordinator.release("movie", ""), "legacy no-ID exit ignored")
	_check(not coordinator.release("other", "a"), "unknown kind exit ignored")
	_check(coordinator.pause_token() == mixed_token, "unknown exits preserve generation")
	_check(coordinator.release("game", "b"), "game exit retires only game")
	_check(coordinator.owns("movie", "a"), "movie survives game exit")
	_check(not coordinator.should_pause_for_token(mixed_token), "exit invalidates old pause timer")
	_check(coordinator.has_owners(), "movie still requires pause")
	_check(not coordinator.release("game", "b"), "duplicate game exit ignored")
	_check(coordinator.claim("game", "a"), "same session text in other kind independent")
	_check(coordinator.owner_count() == 2, "same text distinct owners")
	_check(coordinator.release("movie", "a"), "movie exit leaves game owner")
	_check(coordinator.owns("game", "a"), "game owner survives movie exit")
	_check(coordinator.release("game", "a"), "last owner exits")
	_check(not coordinator.has_owners(), "no owners after final exit")
	_check(not coordinator.should_pause_for_token(coordinator.pause_token()), "empty owners cannot pause")
	_check(coordinator.claim("movie", "before-disconnect"), "pre-disconnect owner added")
	var old_token: int = coordinator.pause_token()
	coordinator.reset_on_disconnect()
	_check(not coordinator.has_owners(), "disconnect clears all owners")
	_check(not coordinator.should_pause_for_token(old_token), "disconnect invalidates pending pause")
	_check(not coordinator.release("movie", "before-disconnect"), "late exit after disconnect ignored")
	_check(coordinator.claim("movie", "after-reconnect"), "reconnected session can claim")
	_check(not coordinator.should_pause_for_token(old_token), "old connection token stays stale")
	var new_token: int = coordinator.pause_token()
	coordinator.invalidate_pending_pause()
	_check(coordinator.owns("movie", "after-reconnect"), "timer cancel preserves owner")
	_check(not coordinator.should_pause_for_token(new_token), "timer cancellation invalidates token")
	_check(coordinator.should_pause_for_token(coordinator.pause_token()), "new token still pauses active owner")
	_check(coordinator.release("movie", "after-reconnect"), "reconnected session released")
	if failures == 0 and checks == 44:
		print("RENDER OWNERSHIP CONTRACT PASS: 44 checks")
		get_tree().quit(0)
	else:
		push_error("RENDER OWNERSHIP CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
