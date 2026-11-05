extends Node

const CLIENT_SCRIPT: Script = preload("res://scripts/backend_client.gd")
const OWNER_SCRIPT: Script = preload("res://scripts/render_ownership_coordinator.gd")
var checks: int = 0
var failures: int = 0
var observed: Array[Dictionary] = []

func _ready() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("[PASS] ", label)
    else:
        failures += 1
        push_error("[FAIL] " + label)

func _capture(_event_type: String, payload: Dictionary) -> void:
    observed.append(payload)

func _run() -> void:
    var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    _check(source.contains("backend.event_epoch_matches(payload)"), "main rejects mismatched playback epochs")
    _check(source.contains('event_type == "movie.exited" or event_type == "game.running" or event_type == "game.exited"'), "all playback events guarded")
    _check(source.contains("_render_ownership.reset_on_disconnect()"), "disconnect resets ownership")
    var client: Node = CLIENT_SCRIPT.new()
    add_child(client)
    client.set_process(false)
    client.event_received.connect(_capture)
    _check(client.connection_epoch() == 0, "epoch initially zero")
    _check(not client.event_epoch_matches({}), "untagged event rejected")
    var _result: int = client.connect_backend()
    client.set_process(false)
    var first_epoch: int = client.connection_epoch()
    _check(first_epoch == 1, "first connection attempt increments epoch")
    _check(client.event_epoch_matches({"__g3_connection_epoch": first_epoch}), "current epoch accepted")
    _check(not client.event_epoch_matches({"__g3_connection_epoch": 0}), "older epoch rejected")
    _check(not client.event_epoch_matches({}), "missing epoch rejected")
    _check(not client.event_epoch_matches({"__g3_connection_epoch": -1}), "negative epoch rejected")
    client._handle_text(JSON.stringify({"type": "game.running", "payload": {"play_session_id": "old-game", "item_id": "a"}}))
    _check(observed.size() == 1, "game running forwarded once")
    var old_event: Dictionary = observed[0]
    _check(client.event_epoch_matches(old_event), "game running stamped locally")
    _check(str(old_event.get("play_session_id", "")) == "old-game", "game session preserved")
    _result = client.connect_backend()
    client.set_process(false)
    var next_epoch: int = client.connection_epoch()
    _check(next_epoch == first_epoch + 1, "reconnect advances epoch")
    _check(not client.event_epoch_matches(old_event), "old running event rejected after reconnect")
    client._handle_text(JSON.stringify({"type": "game.exited", "payload": {"play_session_id": "old-game"}}))
    _check(observed.size() == 2, "game exit forwarded once")
    _check(client.event_epoch_matches(observed[1]), "new connection exit stamped")
    client._handle_text(JSON.stringify({"type": "movie.exited", "payload": {"play_session_id": "movie-1", "__g3_connection_epoch": first_epoch}}))
    _check(observed.size() == 3, "movie exit forwarded")
    _check(client.event_epoch_matches(observed[2]), "untrusted epoch overwritten locally")
    _check(int(observed[2].get("__g3_connection_epoch", -1)) == next_epoch, "socket epoch wins over payload field")
    var owner: Node = OWNER_SCRIPT.new()
    add_child(owner)
    _check(owner.claim("game", "old-game"), "old session initially owns render")
    owner.reset_on_disconnect()
    _check(not owner.has_owners(), "disconnect clears old session")
    _check(not client.event_epoch_matches(old_event), "late old event remains invalid")
    _check(owner.claim("game", "new-game"), "new connection session claims")
    _check(owner.owns("game", "new-game"), "new connection owner retained")
    _check(not owner.release("game", "old-game"), "old session cannot release new owner")
    _check(owner.release("game", "new-game"), "new owner releases normally")
    if failures == 0 and checks == 27:
        print("BACKEND CONNECTION EPOCH CONTRACT PASS: 27 checks")
        get_tree().quit(0)
    else:
        push_error("BACKEND CONNECTION EPOCH CONTRACT FAIL: %d/%d" % [failures, checks])
        get_tree().quit(1)
