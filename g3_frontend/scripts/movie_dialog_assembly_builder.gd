extends RefCounted

# UI-S4b: 仅创建并装配弹窗；信号回调由 main.gd 传入。
const GAME_BLANK_MENU_SCRIPT: Script = preload("res://scripts/game_blank_menu.gd")
const MOVIE_BLANK_MENU_SCRIPT: Script = preload("res://scripts/movie_blank_menu.gd")
const MOVIE_EPISODE_DRAWER_SCRIPT: Script = preload("res://scripts/movie_episode_drawer.gd")
const MOVIE_MANAGE_MENU_SCRIPT: Script = preload("res://scripts/movie_manage_menu.gd")
const MOVIE_METADATA_DIALOG_SCRIPT: Script = preload("res://scripts/movie_metadata_dialog.gd")
const TMDB_DIALOG_SCRIPT: Script = preload("res://scripts/tmdb_search_dialog.gd")
const TMDB_POSTER_DIALOG_SCRIPT: Script = preload("res://scripts/tmdb_poster_dialog.gd")

func build(owner: Node, ui: Control, callbacks: Dictionary) -> Dictionary:
	var movie_manage_menu = MOVIE_MANAGE_MENU_SCRIPT.new()
	movie_manage_menu.action_requested.connect(callbacks["_on_movie_manage_action_requested"])
	ui.add_child(movie_manage_menu)
	var movie_blank_menu = MOVIE_BLANK_MENU_SCRIPT.new()
	movie_blank_menu.action_requested.connect(callbacks["_on_movie_blank_action_requested"])
	ui.add_child(movie_blank_menu)
	var game_blank_menu = GAME_BLANK_MENU_SCRIPT.new()
	game_blank_menu.action_requested.connect(callbacks["_on_game_blank_action_requested"])
	ui.add_child(game_blank_menu)
	var movie_remove_confirm = ConfirmationDialog.new()
	movie_remove_confirm.title = "移除电影档案"
	movie_remove_confirm.ok_button_text = "移除"
	movie_remove_confirm.cancel_button_text = "取消"
	movie_remove_confirm.confirmed.connect(callbacks["_on_movie_remove_confirmed"])
	owner.add_child(movie_remove_confirm)
	var movie_cover_file_dialog = FileDialog.new()
	movie_cover_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	movie_cover_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	movie_cover_file_dialog.filters = PackedStringArray([
		"*.jpg ; JPEG", "*.jpeg ; JPEG", "*.png ; PNG",
		"*.webp ; WebP", "*.bmp ; BMP",
	])
	movie_cover_file_dialog.size = Vector2i(920, 620)
	movie_cover_file_dialog.file_selected.connect(callbacks["_on_movie_cover_file_selected"])
	ui.add_child(movie_cover_file_dialog)
	var movie_metadata_dialog = MOVIE_METADATA_DIALOG_SCRIPT.new()
	movie_metadata_dialog.save_requested.connect(callbacks["_on_movie_metadata_save_requested"])
	owner.add_child(movie_metadata_dialog)
	var movie_backdrop_file_dialog = FileDialog.new()
	movie_backdrop_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	movie_backdrop_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	movie_backdrop_file_dialog.filters = PackedStringArray([
		"*.jpg ; JPEG", "*.jpeg ; JPEG", "*.png ; PNG",
		"*.webp ; WebP", "*.bmp ; BMP",
	])
	movie_backdrop_file_dialog.size = Vector2i(920, 620)
	movie_backdrop_file_dialog.file_selected.connect(callbacks["_on_movie_backdrop_file_selected"])
	ui.add_child(movie_backdrop_file_dialog)
	var movie_episode_drawer = MOVIE_EPISODE_DRAWER_SCRIPT.new()
	movie_episode_drawer.episode_clicked.connect(callbacks["_on_movie_episode_clicked"])
	ui.add_child(movie_episode_drawer)
	var tmdb_dialog = TMDB_DIALOG_SCRIPT.new()
	tmdb_dialog.search_requested.connect(callbacks["_on_tmdb_search_requested"])
	tmdb_dialog.apply_requested.connect(callbacks["_on_tmdb_apply_requested"])
	owner.add_child(tmdb_dialog)
	var tmdb_poster_dialog = TMDB_POSTER_DIALOG_SCRIPT.new()
	tmdb_poster_dialog.poster_list_requested.connect(callbacks["_on_poster_list_requested"])
	tmdb_poster_dialog.thumb_requested.connect(callbacks["_on_poster_thumb_requested"])
	tmdb_poster_dialog.poster_apply_requested.connect(callbacks["_on_poster_apply_requested"])
	owner.add_child(tmdb_poster_dialog)

	return {
		"movie_manage_menu": movie_manage_menu,
		"movie_blank_menu": movie_blank_menu,
		"game_blank_menu": game_blank_menu,
		"movie_remove_confirm": movie_remove_confirm,
		"movie_cover_file_dialog": movie_cover_file_dialog,
		"movie_metadata_dialog": movie_metadata_dialog,
		"movie_backdrop_file_dialog": movie_backdrop_file_dialog,
		"movie_episode_drawer": movie_episode_drawer,
		"tmdb_dialog": tmdb_dialog,
		"tmdb_poster_dialog": tmdb_poster_dialog,
	}
