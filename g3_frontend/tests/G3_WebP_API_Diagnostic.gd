extends SceneTree

const EXTENSION_PATH: String = "res://addons/godot_animated_image/bin/godot_animated_image.gdextension"
const TEST_PATH: String = "C:/Users/HUOX1/AppData/Local/G3/covers/games/战神 起源/cover.webp"

func _initialize() -> void:
	call_deferred("_run")

func _describe(value: Variant) -> String:
	if value == null:
		return "null"
	if value is Texture2D:
		var texture: Texture2D = value as Texture2D
		return "class=%s size=%dx%d" % [texture.get_class(), texture.get_width(), texture.get_height()]
	return "type=%s value=%s" % [type_string(typeof(value)), str(value)]

func _run() -> void:
	print("=== G3 WebP API 分阶段诊断 ===")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = "probe_file"
	if not args.is_empty():
		mode = args[0]
	print("测试模式：", mode)
	print("测试文件存在：", FileAccess.file_exists(TEST_PATH))
	var extension_resource: Resource = load(EXTENSION_PATH) as Resource
	print("扩展资源加载成功：", extension_resource != null)
	print("AnimatedImageLoader 已注册：", ClassDB.class_exists(&"AnimatedImageLoader"))
	if not ClassDB.class_exists(&"AnimatedImageLoader"):
		print("扩展未注册，停止测试。")
		quit(2)
		return

	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.READ)
	if file == null:
		print("无法打开测试文件，错误码：", FileAccess.get_open_error())
		quit(3)
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	print("文件字节数：", bytes.size())
	print("开始调用：", mode)

	match mode:
		"probe_file":
			var result: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"probe_file", TEST_PATH)
			print("probe_file 返回：", result)
		"probe_bytes":
			var result: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"probe_bytes", bytes)
			print("probe_bytes 返回：", result)
		"poster_file":
			var result: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_poster_from_file", TEST_PATH)
			print("load_poster_from_file 返回：", _describe(result))
		"poster_bytes":
			var result: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_poster_from_bytes", bytes)
			print("load_poster_from_bytes 返回：", _describe(result))
		"animated_file":
			var result: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_from_file", TEST_PATH)
			print("load_from_file 返回：", _describe(result))
		"animated_bytes":
			var result: Variant = ClassDB.class_call_static(&"AnimatedImageLoader", &"load_from_bytes", bytes, "webp", {})
			print("load_from_bytes 返回：", _describe(result))
		_:
			print("未知模式。可用：probe_file, probe_bytes, poster_file, poster_bytes, animated_file, animated_bytes")
	print("=== 当前模式结束 ===")
	quit(0)
