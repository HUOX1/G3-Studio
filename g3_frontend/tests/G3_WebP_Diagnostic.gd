extends SceneTree

const TEST_PATH := "C:/Users/HUOX1/AppData/Local/G3/covers/games/战神 起源/cover.webp"

func _initialize() -> void:
	call_deferred("_run_diagnostic")

func _describe_texture(value: Variant) -> String:
	if value == null:
		return "null"
	if not (value is Texture2D):
		return "type=%s value=%s" % [type_string(typeof(value)), str(value)]
	var texture := value as Texture2D
	var result := "class=%s size=%dx%d" % [texture.get_class(), texture.get_width(), texture.get_height()]
	if texture.has_method("get_frame_count"):
		result += " frames=%s" % str(texture.call("get_frame_count"))
		if texture.has_method("get_frame_texture"):
			var frame: Texture2D = texture.call("get_frame_texture", 0) as Texture2D
			result += " frame0=%s" % ("valid" if frame != null else "null")
	return result

func _run_diagnostic() -> void:
	print("=== G3 WebP 诊断开始 ===")
	print("测试文件：", TEST_PATH)
	print("AnimatedImageLoader 存在：", ClassDB.class_exists(&"AnimatedImageLoader"))
	print("AnimatedImagePlayer 存在：", ClassDB.class_exists(&"AnimatedImagePlayer"))

	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	if file == null:
		print("文件打开失败，错误码：", FileAccess.get_open_error())
		quit(2)
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	print("文件字节数：", bytes.size())
	print("文件头（前 32 字节）：", bytes.slice(0, mini(bytes.size(), 32)).hex_encode())

	if not ClassDB.class_exists(&"AnimatedImageLoader"):
		print("原生扩展类未注册，后续扩展 API 测试跳过。")
		quit(0)
		return

	var probe_file: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"probe_file", TEST_PATH)
	var probe_bytes: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"probe_bytes", bytes)
	print("probe_file：", probe_file)
	print("probe_bytes：", probe_bytes)

	var poster_file: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_poster_from_file", TEST_PATH)
	var poster_bytes: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_poster_from_bytes", bytes)
	print("poster_from_file：", _describe_texture(poster_file))
	print("poster_from_bytes：", _describe_texture(poster_bytes))

	var animated_file: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_from_file", TEST_PATH)
	var animated_bytes: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_from_bytes", bytes, "webp", {})
	print("load_from_file：", _describe_texture(animated_file))
	print("load_from_bytes：", _describe_texture(animated_bytes))
	print("=== G3 WebP 诊断结束 ===")
	quit(0)
