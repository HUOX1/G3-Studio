extends SceneTree

const GALLERY: Script = preload("res://scripts/archive_gallery.gd")
var gallery: Node3D
var launches: int = 0
var failures: int = 0
var checks: int = 0
var output: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, context: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ARCHIVE CHECK FAILED: " + context)

func _invariant(count: int) -> void:
	var offsets: Array[int] = []
	var ids: Array[int] = []
	for c: Dictionary in gallery._cases:
		var node: Node3D = c["node"]
		if node.visible:
			offsets.append(int(node.get_meta("offset")))
			ids.append(int(node.get_meta("game_index")))
	_check(offsets.size() == mini(11, count), "visible case count")
	for offset: int in offsets:
		_check(offsets.count(offset) == 1, "unique physical slots")
	for id: int in ids:
		_check(ids.count(id) == 1, "unique games")
	if count > 0:
		_check(offsets.has(0), "one focus")
		for c: Dictionary in gallery._cases:
			var node: Node3D = c["node"]
			if node.visible:
				_check(int(node.get_meta("game_index")) == wrapi(gallery._selection + int(node.get_meta("offset")), 0, count), "game/slot identity")

func _run() -> void:
	# This test process must never authenticate to a running user backend.
	OS.set_environment("G3_WS_TOKEN", "")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
	root.size = Vector2i(1600, 900)
	var shared := Camera3D.new()
	shared.position = Vector3(1, 2, 7.2)
	root.add_child(shared)
	var before: Transform3D = shared.transform
	gallery = GALLERY.new()
	root.add_child(gallery)
	gallery.configure(shared)
	var font_path: String = OS.get_environment("G3_TEST_FONT")
	if not font_path.is_empty():
		var test_font := FontFile.new()
		test_font.load_dynamic_font(font_path)
		var regular := FontVariation.new()
		regular.base_font = test_font
		regular.variation_opentype = {"wght":400.0}
		var semibold := FontVariation.new()
		semibold.base_font = test_font
		semibold.variation_opentype = {"wght":600.0}
		gallery._root.theme.default_font = regular
		gallery._title.add_theme_font_override("font", semibold)
		gallery._brand.add_theme_font_override("font", semibold)
	gallery.game_launch_requested.connect(func(_game: Dictionary): launches += 1)
	gallery.set_section_visible(true)
	for count in [0, 1, 2, 7, 11, 17]:
		var data: Array[Dictionary] = []
		for i in range(count):
			data.append({"id":str(i + 1), "title":"测试藏品 %02d" % i, "platform":"PC", "cover":"", "playable":true})
		gallery.set_games(data)
		if count == 0:
			await _capture("empty")
		_invariant(count)
		for step in range(count * 3):
			gallery._shift(1)
			_invariant(count)
		for step in range(count):
			gallery._select((step * 7) % count)
			_invariant(count)
	_check(launches == 0, "browsing never launches")
	gallery._set_detail(true)
	_check(gallery._description_scroll.visible, "detail enters")
	gallery._set_detail(false)
	_check(not gallery._description_scroll.visible, "detail returns")
	gallery._request_launch()
	gallery._request_launch()
	_check(launches == 1, "duplicate launch suppressed")
	gallery.set_launch_result(false, "测试错误")
	_check(gallery._status.text.contains("测试错误"), "visible launch failure")
	gallery._open_index()
	gallery._filter_index("测试藏品 03")
	_check(gallery._result_ids.size() == 1, "real index filtering")
	gallery._activate_result(0)
	_check(gallery._selection == 3 and not gallery._search.visible, "index focuses without launch")
	_check(launches == 1, "index never launches")
	gallery._filter_index("not-a-match")
	_check(gallery._result_ids.is_empty(), "zero search results safe")
	gallery._games[gallery._selection]["playable"] = false
	gallery._request_launch()
	_check(launches == 1, "unplayable game does not launch")
	gallery._open_index()
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	_check(not gallery._search.visible, "real Escape input closes focused index")
	var test_dir: String = OS.get_environment("TEMP") if OS.has_environment("TEMP") else "/tmp"
	test_dir = test_dir.path_join("g3-archive-smoke-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(test_dir)
	var data: Array[Dictionary] = []
	var titles: Array[String] = ["星际拓荒", "沉默的远洋", "THE LAST\nTRANSMISSION", "光与影：远征", "AERIS", "深空档案", "Beyond the northern horizon", "极乐迪斯科", "空洞骑士", "收集光的旅人", "雾港"]
	for i in range(11):
		var path: String = test_dir.path_join("cover_%d.png" % i)
		var im := Image.create(600, 900, false, Image.FORMAT_RGB8)
		im.fill(Color.from_hsv(float(i) / 12, 0.42, 0.55))
		im.save_png(path)
		# Optional original procedural test artwork. Never shipped as a G3 asset.
		var preview: String = "/tmp/g3-fixture-art/cover_%d.png" % i
		if FileAccess.file_exists(preview):
			path = preview
		data.append({"id":str(i + 1), "title":titles[i], "cover":path, "platform":"PC", "source":"Steam", "playable":true, "playtime_seconds":147500, "description":"这是一组用于验证构图、文字与异步封面加载的测试档案。实际运行时，这里显示 G3 收藏库中已有的游戏简介。\n\n玻璃外壳与封面保持连续的位置关系；返回后保留当前选择。", "genres":"冒险 / 探索"})
	gallery.set_games(data)
	# Rapid remapping while workers are running must not attach old covers to new slots.
	for i in range(25):
		gallery._shift(1)
	gallery._selection = 0
	gallery._bind_cases()
	var deadline: int = Time.get_ticks_msec() + 8000
	while not gallery._loading.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(gallery._loading.is_empty(), "workers complete")
	for c: Dictionary in gallery._cases:
		var node: Node3D = c["node"]
		var index: int = int(node.get_meta("game_index"))
		_check(str(node.get_meta("path")) == data[index]["cover"], "async slot path matches game")
		_check(bool((c["cover"] as ShaderMaterial).get_shader_parameter("use_texture")), "texture uploaded")
		_check((c["cover"] as ShaderMaterial).get_shader_parameter("cover_texture") == gallery._cache[str(node.get_meta("path"))]["texture"], "async texture identity matches latest game")
	gallery._update_scene(1.0, true)
	await _capture("browse")
	# Hit testing uses the actual current transforms, not target screen rectangles.
	for c: Dictionary in gallery._cases:
		var node: Node3D = c["node"]
		if int(node.get_meta("offset")) == 0:
			var at: Vector2 = gallery._camera.unproject_position(node.global_position)
			var mouse := InputEventMouseButton.new()
			mouse.position = at
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = true
			gallery._unhandled_input(mouse)
			_check(launches == 1, "single click never launches")
			mouse.double_click = true
			gallery._unhandled_input(mouse)
			_check(gallery._detail, "double click opens detail")
			break
	gallery._update_scene(1.0, true)
	await _capture("detail")
	var glass_camera: Transform3D = gallery._camera.transform
	gallery._toggle_glass()
	gallery._update_scene(1.0, true)
	_check(gallery._camera.transform == glass_camera, "glass toggle preserves view")
	await _capture("frosted")
	gallery._set_detail(false)
	gallery._toggle_glass()
	root.size = Vector2i(1244, 700)
	await process_frame
	gallery._resize()
	await _capture("compact")
	gallery.set_section_visible(false)
	_check(shared.transform == before, "shared camera is untouched")
	_check(gallery._viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden world stops rendering")
	var preview_theme: Theme = gallery._root.theme
	gallery.set_section_visible(true)
	var missing_games: Array[Dictionary] = [{"id":"missing", "title":"缺失封面", "cover":test_dir.path_join("missing.png")}]
	gallery.set_games(missing_games)
	_check((gallery._cases[0]["fallback"] as Label3D).visible, "missing cover keeps title fallback")
	var invalid_path: String = test_dir.path_join("invalid.png")
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string("expected invalid PNG fixture")
	invalid_file.close()
	var broken_games: Array[Dictionary] = [{"id":"broken", "title":"损坏封面", "cover":invalid_path}]
	gallery.set_games(broken_games)
	while not gallery._loading.is_empty():
		await process_frame
	_check((gallery._cases[0]["fallback"] as Label3D).visible, "failed decode keeps title fallback")
	gallery.queue_free()
	await process_frame
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._pending_games_id = "archive-smoke-list"
	main._on_backend_response("archive-smoke-list", true, data, {})
	main._apply_section_now(3)
	main.archive_gallery._root.theme = preview_theme
	if not font_path.is_empty():
		main.archive_gallery._title.add_theme_font_override("font", preview_theme.default_font)
		main.archive_gallery._brand.add_theme_font_override("font", preview_theme.default_font)
	await _capture("integrated")
	main.archive_gallery._open_index()
	await _capture("index")
	main.archive_gallery._close_index()
	_check(main.archive_gallery._active, "MUSIC enters archive in real main scene")
	_check(main.archive_gallery._games.size() == data.size(), "real response handler supplies games")
	main.archive_gallery._request_launch()
	_check(main.archive_gallery._status.text.contains("后端未连接"), "offline launch failure shown inside archive")
	main._apply_section_now(2)
	_check(not main.archive_gallery._active, "leaving stops archive")
	_check(main.spatial_gallery.visible, "existing spatial section still enters")
	main._apply_section_now(0)
	_check(main.game_section.visible, "main game section still enters")
	main.queue_free()
	await process_frame
	for i in range(11):
		DirAccess.remove_absolute(test_dir.path_join("cover_%d.png" % i))
	DirAccess.remove_absolute(invalid_path)
	DirAccess.remove_absolute(test_dir)
	print("ARCHIVE_SMOKE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(output)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
