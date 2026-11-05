extends Node
## G3 UI 音效管理器（Autoload 名：UISfx）
##
## 职责边界：
##   - 只负责 UI 交互反馈音，不接管其他音频播放。
##   - 建立独立 "UI" 总线，UI 音量与静音不影响其他音频播放。
##   - 素材缺失、总线创建失败、设置异常一律静默降级，绝不抛错、绝不打断启动。
##
## 时间点不在此处：启动音由 main.gd 在图标动画真正开始时调用，管理器只负责"怎么播"。

const AUDIO_FILE_LOADER_SCRIPT: Script = preload("res://scripts/audio_file_loader.gd")

const AUDIO_DIR: String = "res://assets/audio/"
const UI_BUS_NAME: String = "UI"
const DEFAULT_VOLUME: float = 0.8

# id -> 文件名。换素材只改这里，播放逻辑不动。
const SFX_FILES: Dictionary = {
	&"boot": "ui_boot_final.wav",
	&"detail_in": "",  # Removed: entering detail no longer produces a sound.
	&"detail_out": "ui_detail_close.wav",
	&"card_click": "ui_card_click.wav",
	&"game_launch": "ui_drive_contact.wav",
	&"drive_draw": "ui_drive_draw.wav",
	&"drive_read": "ui_drive_read.wav",
	&"launch_unavailable": "ui_launch_unavailable.wav",
	&"sort_cycle": "ui_sort_cycle.wav",
	&"section_switch": "ui_section_switch.wav",
}

# 各音效相对 UI 总音量的增益（dB）。boot 唯一允许偏响——它每次启动只出现一次。
const SFX_GAIN_DB: Dictionary = {
	&"boot": -3.0,
	&"detail_in": -18.0,
	&"detail_out": -1.0,
	&"card_click": -1.0,
	&"game_launch": 0.5,
	&"drive_draw": -1.0,
	&"drive_read": -3.0,
	&"launch_unavailable": -2.0,
	&"sort_cycle": -3.0,
	&"section_switch": -5.0,

}

# 同一 id 两次播放的最小间隔（毫秒），防止连击叠加成噪音。
const SFX_MIN_INTERVAL_MS: Dictionary = {
	&"boot": 0,
	&"detail_in": 160,
	&"detail_out": 120,
	&"card_click": 80,
	&"game_launch": 250,
	&"drive_draw": 250,
	&"drive_read": 250,
	&"launch_unavailable": 350,
	&"sort_cycle": 90,
	&"section_switch": 110,
}

# 播放某 id 之前需要先掐断的 id：退出音截断进入音拖尾，避免两个方向的声音叠在一起。
const SFX_CANCELS: Dictionary = {
	&"detail_out": [&"detail_in"],
}

var enabled: bool = true
var volume: float = DEFAULT_VOLUME

const MAX_IMPORT_BYTES: int = 10 * 1024 * 1024
const CUSTOM_DIR: String = "user://g3_ui_sfx/"
var overrides: Dictionary = {}
var _streams: Dictionary = {}
var _players: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _bus_index: int = -1


func _ready() -> void:
	# 暂停游戏时不至于把 UI 反馈音一起冻住。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bus()
	_load_streams()
	_create_players()


## 独立 UI 总线：已存在就复用，不存在则运行时创建并送回 Master。
## 刻意不新增 .tres 总线布局文件，避免多一个需要维护的资源。
func _setup_bus() -> void:
	var index: int = AudioServer.get_bus_index(UI_BUS_NAME)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(index, UI_BUS_NAME)
		AudioServer.set_bus_send(index, "Master")
	_bus_index = index


## 预加载全部音效。Autoload 早于主场景，正好用启动期把 WAV 读进内存，
## 首帧播放时不再有磁盘 I/O，避免拖慢启动。
func _load_streams() -> void:
	for id in SFX_FILES:
		# Empty slots intentionally have no bundled sound file.
		if str(SFX_FILES[id]).is_empty():
			continue
		var path: String = AUDIO_DIR + str(SFX_FILES[id])
		if not FileAccess.file_exists(path):
			# 素材缺失：跳过即可，play() 会因为找不到 player 而静默返回。
			continue
		# 复用项目既有加载器，直接读文件，不依赖 .import 缓存。
		var stream: AudioStream = AUDIO_FILE_LOADER_SCRIPT.load_audio(ProjectSettings.globalize_path(path), false)
		if stream != null:
			_streams[id] = stream


## 每个音效固定一个播放器，天然做到"同一音效永不叠加"。
func _create_players() -> void:
	for id in _streams:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Sfx_" + str(id)
		player.stream = _streams[id]
		player.max_polyphony = 1
		if _bus_index >= 0:
			player.bus = UI_BUS_NAME
		add_child(player)
		_players[id] = player


func play(id: StringName, exclusive: bool = false) -> void:
	if not enabled or volume <= 0.0:
		return
	if not _players.has(id):
		return
	var now: int = Time.get_ticks_msec()
	var gap: int = int(SFX_MIN_INTERVAL_MS.get(id, 80))
	if _last_play_ms.has(id) and now - int(_last_play_ms[id]) < gap:
		return
	_last_play_ms[id] = now

	if SFX_CANCELS.has(id):
		for other in SFX_CANCELS[id]:
			_stop(other)
	if exclusive:
		stop_all()

	var player: AudioStreamPlayer = _players[id]
	player.volume_db = float(SFX_GAIN_DB.get(id, -18.0)) + linear_to_db(maxf(volume, 0.0001))
	player.play()


# Skip the intro without a hard cut; normal playback is never trimmed.
func fade_out(id: StringName, seconds: float = 0.16) -> void:
	if not _players.has(id):
		return
	var player: AudioStreamPlayer = _players[id]
	if not is_instance_valid(player) or not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -70.0, maxf(seconds, 0.01))
	tween.tween_callback(player.stop)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop_all()


func toggle_enabled() -> bool:
	set_enabled(not enabled)
	return enabled


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	if volume <= 0.0:
		stop_all()
		return
	for id in _players:
		var player: AudioStreamPlayer = _players[id]
		player.volume_db = float(SFX_GAIN_DB.get(id, -18.0)) + linear_to_db(maxf(volume, 0.0001))


func stop_all() -> void:
	for id in _players:
		_stop(id)


func _stop(id: StringName) -> void:
	if not _players.has(id):
		return
	var player: AudioStreamPlayer = _players[id]
	if player != null and player.playing:
		player.stop()


## 供排查用：返回已成功加载的音效 id，素材缺失时方便定位。
func loaded_ids() -> Array:
	return _players.keys()


func effective_filename(id: String) -> String:
	if not SFX_FILES.has(id):
		return ""
	if overrides.has(id) and _streams.has(StringName(id)):
		return str(overrides[id]).get_file()
	var builtin: String = str(SFX_FILES[id])
	return builtin if not builtin.is_empty() else "未设置"


func effective_source(id: String) -> String:
	if overrides.has(id) and _streams.has(StringName(id)):
		return "自定义"
	return "未设置" if str(SFX_FILES.get(id, "")).is_empty() else "内置"


func apply_overrides(values: Dictionary) -> Array[String]:
	overrides.clear()
	var missing: Array[String] = []
	for id in SFX_FILES:
		var name: String = str(id)
		var path: String = str(values.get(name, ""))
		if path.is_empty():
			_apply_stream(name, _builtin_stream(name))
			continue
		if not path.begins_with(CUSTOM_DIR):
			missing.append(name)
			_apply_stream(name, _builtin_stream(name))
			continue
		var stream: AudioStream = _load_validated(path)
		if stream == null:
			missing.append(name)
			_apply_stream(name, _builtin_stream(name))
		else:
			_apply_stream(name, stream)
			overrides[name] = path
	return missing


func _builtin_stream(id: String) -> AudioStream:
	var filename: String = str(SFX_FILES.get(id, ""))
	if filename.is_empty():
		return null
	return AUDIO_FILE_LOADER_SCRIPT.load_audio(ProjectSettings.globalize_path(AUDIO_DIR + filename), false)


func _load_validated(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var size: int = file.get_length()
	file.close()
	if size < 32 or size > MAX_IMPORT_BYTES:
		return null
	if path.get_extension().to_lower() not in ["wav", "mp3", "ogg"]:
		return null
	return AUDIO_FILE_LOADER_SCRIPT.load_audio(ProjectSettings.globalize_path(path), false)


func _apply_stream(id: String, stream: AudioStream) -> void:
	var key: StringName = StringName(id)
	if stream == null:
		_streams.erase(key)
		if _players.has(key):
			var old_player: AudioStreamPlayer = _players[key]
			old_player.stop()
			_players.erase(key)
			old_player.queue_free()
		return
	_streams[key] = stream
	if _players.has(key):
		var player: AudioStreamPlayer = _players[key]
		player.stop()
		player.stream = stream
	else:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_" + id
		player.stream = stream
		player.bus = UI_BUS_NAME
		player.max_polyphony = 1
		add_child(player)
		_players[key] = player


# Returns {ok, error, path}; no current stream or mapping is modified on failure.
func import_sound(id: String, source: String) -> Dictionary:
	if not SFX_FILES.has(id):
		return {"ok": false, "error": "未知音效场景"}
	if _load_validated(source) == null:
		return {"ok": false, "error": "不支持、损坏或超过 10 MB 的音频文件"}
	var absolute_dir: String = ProjectSettings.globalize_path(CUSTOM_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return {"ok": false, "error": "无法创建音效存储目录"}
	var target: String = CUSTOM_DIR + id + "_" + str(Time.get_ticks_usec()) + "." + source.get_extension().to_lower()
	var err: Error = DirAccess.copy_absolute(source, ProjectSettings.globalize_path(target))
	if err != OK:
		return {"ok": false, "error": "音效文件复制失败"}
	var loaded: AudioStream = _load_validated(target)
	if loaded == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
		return {"ok": false, "error": "复制后的音效验证失败"}
	return {"ok": true, "path": target, "stream": loaded}


func commit_sound(id: String, path: String, stream: AudioStream) -> void:
	_apply_stream(id, stream)
	overrides[id] = path


func restore_default(id: String) -> void:
	if not SFX_FILES.has(id):
		return
	_apply_stream(id, _builtin_stream(id))
	overrides.erase(id)


func audition(id: String) -> void:
	# Existing boot gain remains unchanged; preview caps boot's relative loudness.
	if not enabled or volume <= 0 or not _players.has(StringName(id)):
		return
	var player: AudioStreamPlayer = _players[StringName(id)]
	player.stop()
	player.volume_db = float(SFX_GAIN_DB.get(id, -18.0)) + linear_to_db(maxf(volume, 0.0001))
	player.play()
