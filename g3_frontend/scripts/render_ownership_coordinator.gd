extends Node

# Stage 6.4: session ownership and exit-before-running tombstones.
# main.gd applies the resulting ownership state to RenderingServer.
# Only confirmed, monitorable sessions with nonempty unique IDs may claim.
# Legacy/unknown events with no ID must never release an unrelated owner.

var _owners: Dictionary = {"movie": {}, "game": {}}
var _pause_generation: int = 0
# An exited session must never be reclaimed by a late game.running event.
# Bounded history avoids unbounded growth during long-running sessions.
const MAX_RETIRED_SESSIONS: int = 512
var _retired: Dictionary = {"movie": {}, "game": {}}
var _retired_order: Array[String] = []

func _valid(kind: String, session_id: String) -> bool:
	return (kind == "movie" or kind == "game") and not session_id.is_empty()

func claim(kind: String, session_id: String) -> bool:
	if not _valid(kind, session_id):
		return false
	if (_retired[kind] as Dictionary).has(session_id):
		return false
	var sessions: Dictionary = _owners[kind]
	if sessions.has(session_id):
		return false
	sessions[session_id] = true
	_pause_generation += 1
	return true

func note_exit(kind: String, session_id: String) -> bool:
	# Record even an exit that arrives before its corresponding running event.
	# This method does not release owners; call release() afterwards.
	if not _valid(kind, session_id):
		return false
	var retired: Dictionary = _retired[kind]
	if retired.has(session_id):
		return false
	retired[session_id] = true
	_retired_order.append(kind + ":" + session_id)
	while _retired_order.size() > MAX_RETIRED_SESSIONS:
		var oldest: String = _retired_order.pop_front()
		var separator: int = oldest.find(":")
		var old_kind: String = oldest.substr(0, separator)
		var old_id: String = oldest.substr(separator + 1)
		(_retired[old_kind] as Dictionary).erase(old_id)
	return true

func release(kind: String, session_id: String) -> bool:
	if not _valid(kind, session_id):
		return false
	var sessions: Dictionary = _owners[kind]
	if not sessions.has(session_id):
		return false
	sessions.erase(session_id)
	_pause_generation += 1
	return true

func owns(kind: String, session_id: String) -> bool:
	if not _valid(kind, session_id):
		return false
	return (_owners[kind] as Dictionary).has(session_id)

func owner_count() -> int:
	return (_owners["movie"] as Dictionary).size() + (_owners["game"] as Dictionary).size()

func has_owners() -> bool:
	return owner_count() > 0

func pause_token() -> int:
	# Capture immediately before scheduling a delayed pause. A changed owner
	# set invalidates the token, even if another owner is still active.
	return _pause_generation

func should_pause_for_token(token: int) -> bool:
	return token == _pause_generation and has_owners()

func invalidate_pending_pause() -> void:
	# Cancel timers without changing the active owners (e.g. a UI transition).
	_pause_generation += 1

func reset_on_disconnect() -> void:
	# Invalidate timers even if there were no owners. Do not reuse tokens.
	(_owners["movie"] as Dictionary).clear()
	(_owners["game"] as Dictionary).clear()
	(_retired["movie"] as Dictionary).clear()
	(_retired["game"] as Dictionary).clear()
	_retired_order.clear()
	_pause_generation += 1
