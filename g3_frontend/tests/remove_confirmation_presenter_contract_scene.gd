extends Node

const PRESENTER: Script = preload("res://scripts/remove_confirmation_presenter.gd")
var checks: int = 0
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[FAIL] " + label)

func _run() -> void:
	var presenter: RefCounted = PRESENTER.new()
	var movie_text: String = presenter.movie_remove_text("测试电影")
	var game_text: String = presenter.game_remove_text("测试游戏")
	_check(movie_text.begins_with("确定从 G3 中移除《测试电影》的档案吗？"), "movie heading")
	_check(game_text.begins_with("确定从 G3 中移除《测试游戏》的档案吗？"), "game heading")
	_check(movie_text.contains("\n\n"), "movie double newline")
	_check(game_text.contains("\n\n"), "game double newline")
	_check(movie_text.contains("不会删除视频文件"), "movie video files preserved")
	_check(movie_text.contains("封面图片"), "movie covers preserved")
	_check(movie_text.contains("其他本地资源"), "movie other resources preserved")
	_check(game_text.contains("不会删除游戏本体"), "game install preserved")
	_check(game_text.contains("封面图片"), "game covers preserved")
	_check(game_text.contains("媒体素材"), "game media preserved")
	_check(game_text.contains("存档"), "game saves preserved")
	_check(not movie_text.contains("游戏本体"), "movie distinct from game")
	_check(not game_text.contains("视频文件"), "game distinct from movie")
	_check(presenter.movie_remove_text("").contains("《》"), "empty movie title")
	_check(presenter.game_remove_text("").contains("《》"), "empty game title")
	_check(presenter.movie_remove_text("A/B").contains("《A/B》"), "movie punctuation title")
	_check(presenter.game_remove_text("A/B").contains("《A/B》"), "game punctuation title")
	var movie_dialog := ConfirmationDialog.new()
	var game_dialog := ConfirmationDialog.new()
	add_child(movie_dialog)
	add_child(game_dialog)
	presenter.show_movie_remove(movie_dialog, "M")
	_check(movie_dialog.dialog_text == presenter.movie_remove_text("M"), "movie dialog text")
	_check(movie_dialog.visible, "movie popup opened")
	_check(not game_dialog.visible, "game dialog still hidden")
	movie_dialog.hide()
	presenter.show_game_remove(game_dialog, "G")
	_check(game_dialog.dialog_text == presenter.game_remove_text("G"), "game dialog text")
	_check(game_dialog.visible, "game popup opened")
	_check(not movie_dialog.visible, "movie dialog stays hidden")
	_check(checks == 23, "check counter")
	if failures == 0 and checks == 24:
		print("REMOVE CONFIRMATION PRESENTER CONTRACT PASS: 24 checks")
	else:
		push_error("REMOVE CONFIRMATION PRESENTER CONTRACT FAIL: %d/%d" % [failures, checks])
	get_tree().quit(0 if failures == 0 and checks == 24 else 1)
