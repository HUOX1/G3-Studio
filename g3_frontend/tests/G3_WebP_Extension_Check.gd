extends SceneTree

const EXTENSION_PATH: String = "res://addons/godot_animated_image/bin/godot_animated_image.gdextension"

func _initialize() -> void:
	call_deferred("_run_check")

func _run_check() -> void:
	print("=== G3 GDExtension 检查开始 ===")
	print("扩展文件存在：", FileAccess.file_exists(EXTENSION_PATH))

	# --script 运行时不一定会像编辑器一样先加载编辑器插件；显式加载 .gdextension，
	# 才能区分“诊断模式没加载扩展”和“扩展 DLL 本身加载失败”。
	var extension_resource: Resource = load(EXTENSION_PATH) as Resource
	print("扩展资源加载成功：", extension_resource != null)
	print("AnimatedImageLoader 已注册：", ClassDB.class_exists(&"AnimatedImageLoader"))
	print("AnimatedImagePlayer 已注册：", ClassDB.class_exists(&"AnimatedImagePlayer"))
	print("ResourceImporterGIFTexture 已注册：", ClassDB.class_exists(&"ResourceImporterGIFTexture"))
	print("=== G3 GDExtension 检查结束，准备退出 ===")
	quit(0)
