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
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	# Injector may restore Windows CRLF; compare normalized line endings.
	var normalized_source: String = source.replace("\r\n", "\n").replace("\r", "\n")
	_check(source.contains("_render_ownership.note_exit(\"game\", exited_session_id)"), "game exits register tombstones")
	_check(source.contains("_render_ownership.note_exit(\"movie\", movie_session_id)"), "movie exits register tombstones")
	_check(normalized_source.contains("_resume_render_if_unowned()\n\t\t\t# An unrelated/early exit must not reset the current launch UI.") and normalized_source.contains("\t\t\treturn\n\t\t_reset_launch_button_after(0.1)"), "unknown game exit does not reset launch UI")
	var owner: Node = COORDINATOR_SCRIPT.new()
	add_child(owner)
	_check(not owner.note_exit("game", ""), "empty exit rejected")
	_check(not owner.note_exit("other", "a"), "unknown kind exit rejected")
	_check(owner.note_exit("game", "game-early"), "exit before running registered")
	_check(not owner.claim("game", "game-early"), "late running cannot resurrect exited game")
	_check(not owner.has_owners(), "early exit leaves render unowned")
	_check(not owner.note_exit("game", "game-early"), "duplicate exit ignored")
	_check(owner.claim("movie", "movie-active"), "movie can own render")
	var movie_token: int = owner.pause_token()
	_check(owner.note_exit("game", "game-late"), "unknown game exit recorded")
	_check(not owner.release("game", "game-late"), "unknown game exit cannot release")
	_check(owner.owns("movie", "movie-active"), "movie survives unknown game exit")
	_check(owner.should_pause_for_token(movie_token), "unknown exit preserves movie pause token")
	_check(not owner.claim("game", "game-late"), "unknown exit blocks late game running")
	_check(owner.claim("game", "game-current"), "new game session can claim")
	_check(owner.owner_count() == 2, "movie and game overlap")
	_check(owner.note_exit("game", "game-current"), "current game exit registered")
	_check(owner.release("game", "game-current"), "current game released")
	_check(not owner.claim("game", "game-current"), "duplicate running after exit rejected")
	_check(owner.owns("movie", "movie-active"), "movie survives game exit")
	_check(owner.note_exit("movie", "movie-active"), "movie exit registered")
	_check(owner.release("movie", "movie-active"), "movie released")
	_check(not owner.has_owners(), "last owner released")
	_check(not owner.claim("movie", "movie-active"), "late movie claim rejected")
	owner.reset_on_disconnect()
	_check(owner.claim("game", "game-early"), "disconnect clears old exit history")
	_check(owner.has_owners(), "reconnected game can own render")
	owner.reset_on_disconnect()
	_check(not owner.has_owners(), "disconnect clears new ownership")
	_check(not owner.should_pause_for_token(movie_token), "old timer cannot fire after disconnect")
	if failures == 0 and checks == 29:
		print("RENDER OWNERSHIP EXIT ORDER CONTRACT PASS: 29 checks")
		get_tree().quit(0)
	else:
		push_error("RENDER OWNERSHIP EXIT ORDER CONTRACT FAIL: %d/%d" % [failures, checks])
		get_tree().quit(1)
