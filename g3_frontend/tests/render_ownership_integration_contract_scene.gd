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
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("const RENDER_OWNERSHIP_SCRIPT:"), "main preloads coordinator")
	_check(main_source.contains("_render_ownership = RENDER_OWNERSHIP_SCRIPT.new()"), "main creates coordinator")
	_check(main_source.contains("_render_ownership.reset_on_disconnect()"), "disconnect resets owners")
	_check(main_source.contains("_render_ownership.claim(\"game\", running_session_id)"), "game running claims identified session")
	_check(main_source.contains("_render_ownership.release(\"game\", exited_session_id)"), "game exit releases identified session")
	_check(main_source.contains("_render_ownership.claim(\"movie\", movie_session_id)"), "movie reply claims identified session")
	_check(main_source.contains("_render_ownership.release(\"movie\", movie_session_id)"), "movie exit releases identified session")
	_check(main_source.contains("_render_ownership.should_pause_for_token(token)"), "delayed pause checks current token")
	_check(main_source.contains("func _resume_render_if_unowned() -> void:"), "guarded resume helper exists")
	_check(not main_source.contains("_delayed_pause_generation"), "legacy generation removed")
	_check(main_source.contains("_resume_render_if_unowned()"), "resume uses guard")
	_check(main_source.contains("func _refresh_render_after_release() -> void:"), "surviving owner reschedules pause")
	_check(main_source.contains("response.get(\"already_exited\", false)"), "early movie exit protected")
	var owner: Node = COORDINATOR_SCRIPT.new()
	add_child(owner)
	_check(not owner.has_owners(), "idle startup")
	_check(owner.claim("game", "game-1"), "game first running event claims")
	var first_token: int = owner.pause_token()
	_check(owner.should_pause_for_token(first_token), "game pause timer valid")
	_check(owner.claim("movie", "movie-1"), "movie overlaps game")
	_check(owner.owner_count() == 2, "two cross-module owners")
	_check(not owner.should_pause_for_token(first_token), "movie arrival invalidates game timer")
	var mixed_token: int = owner.pause_token()
	_check(not owner.release("game", "stale-game"), "stale game exit ignored")
	_check(owner.should_pause_for_token(mixed_token), "stale game exit leaves pause valid")
	_check(owner.release("game", "game-1"), "game exit releases only game")
	_check(owner.owns("movie", "movie-1"), "movie still owns render")
	_check(owner.has_owners(), "game exit cannot resume movie")
	_check(not owner.release("movie", "legacy-no-match"), "unknown movie exit ignored")
	_check(owner.release("movie", "movie-1"), "last movie exit releases")
	_check(not owner.has_owners(), "render may resume after last exit")
	_check(not owner.should_pause_for_token(mixed_token), "old mixed timer invalid")
	_check(owner.claim("game", "game-2"), "new launch claims")
	var second_token: int = owner.pause_token()
	owner.reset_on_disconnect()
	_check(not owner.has_owners(), "disconnect releases all")
	_check(not owner.should_pause_for_token(second_token), "disconnect cancels timer")
	_check(not owner.release("game", "game-2"), "late old-connection exit ignored")
	_check(owner.claim("movie", "movie-2"), "new connection may claim")
	_check(owner.should_pause_for_token(owner.pause_token()), "new connection timer valid")
	_check(not owner.should_pause_for_token(second_token), "old connection token remains stale")
	_check(owner.release("movie", "movie-2"), "new connection releases normally")
	if failures == 0 and checks == 36:
		print("RENDER OWNERSHIP INTEGRATION CONTRACT PASS: 36 checks")
		get_tree().quit(0)
	else:
		push_error("RENDER OWNERSHIP INTEGRATION CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
