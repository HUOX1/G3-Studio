extends RefCounted

# UI-S4c: 仅装配游戏弹窗和连接信号；业务处理与节点引用仍由 main.gd 持有。
const GAME_CREATE_DIALOG_SCRIPT: Script = preload("res://scripts/game_create_dialog.gd")
const GAME_PASTE_IMPORT_DIALOG_SCRIPT: Script = preload("res://scripts/game_paste_import_dialog.gd")
const GAME_SCRAPER_DIALOG_SCRIPT: Script = preload("res://scripts/game_scraper_dialog.gd")
const LIBRARY_SCAN_DIALOG_SCRIPT: Script = preload("res://scripts/library_scan_dialog.gd")
const STEAM_SEARCH_DIALOG_SCRIPT: Script = preload("res://scripts/steam_search_dialog.gd")
const GAME_METADATA_DIALOG_SCRIPT: Script = preload("res://scripts/game_metadata_dialog.gd")
const GAME_LAUNCH_DIALOG_SCRIPT: Script = preload("res://scripts/game_launch_dialog.gd")
const PLAYTIME_EDIT_DIALOG_SCRIPT: Script = preload("res://scripts/playtime_edit_dialog.gd")
const GAME_MANAGE_MENU_SCRIPT: Script = preload("res://scripts/game_manage_menu.gd")

func build_entry(owner: Node, platforms: Array[String], callbacks: Dictionary) -> Dictionary:
	var game_create_dialog = GAME_CREATE_DIALOG_SCRIPT.new()
	game_create_dialog.set_platforms(platforms)
	game_create_dialog.create_requested.connect(callbacks["_on_game_create_requested"])
	owner.add_child(game_create_dialog)
	var game_paste_import_dialog = GAME_PASTE_IMPORT_DIALOG_SCRIPT.new()
	game_paste_import_dialog.apply_requested.connect(callbacks["_on_paste_import_apply"])
	owner.add_child(game_paste_import_dialog)
	return {
		"game_create_dialog": game_create_dialog,
		"game_paste_import_dialog": game_paste_import_dialog,
	}

func build_management(owner: Node, ui: Control, platforms: Array[String], callbacks: Dictionary) -> Dictionary:
	var game_scraper_dialog = GAME_SCRAPER_DIALOG_SCRIPT.new()
	game_scraper_dialog.search_requested.connect(callbacks["_on_sgdb_search_requested"])
	game_scraper_dialog.assets_requested.connect(callbacks["_on_sgdb_assets_requested"])
	game_scraper_dialog.asset_info_requested.connect(callbacks["_on_sgdb_asset_info_requested"])
	game_scraper_dialog.apply_requested.connect(callbacks["_on_sgdb_apply_requested"])
	owner.add_child(game_scraper_dialog)

	# 旧的 4 个独立扫描对话框不再实例化（脚本保留在 scripts/ 下备用）
	var library_scan_dialog = LIBRARY_SCAN_DIALOG_SCRIPT.new()
	library_scan_dialog.scan_requested.connect(callbacks["_on_library_scan_requested"])
	library_scan_dialog.import_requested.connect(callbacks["_on_library_scan_import_requested"])
	library_scan_dialog.closed.connect(callbacks["_on_library_scan_dialog_closed"])
	owner.add_child(library_scan_dialog)

	var game_manage_menu = GAME_MANAGE_MENU_SCRIPT.new()
	game_manage_menu.action_requested.connect(callbacks["_on_game_manage_action"])
	ui.add_child(game_manage_menu)

	var steam_search_dialog = STEAM_SEARCH_DIALOG_SCRIPT.new()
	steam_search_dialog.search_requested.connect(callbacks["_on_steam_search_requested"])
	steam_search_dialog.apply_requested.connect(callbacks["_on_steam_apply_requested"])
	owner.add_child(steam_search_dialog)

	var game_metadata_dialog = GAME_METADATA_DIALOG_SCRIPT.new()
	game_metadata_dialog.set_platforms(platforms)
	game_metadata_dialog.save_requested.connect(callbacks["_on_game_metadata_save_requested"])
	owner.add_child(game_metadata_dialog)

	var game_launch_dialog = GAME_LAUNCH_DIALOG_SCRIPT.new()
	game_launch_dialog.save_requested.connect(callbacks["_on_game_launch_save_requested"])
	owner.add_child(game_launch_dialog)

	var playtime_edit_dialog = PLAYTIME_EDIT_DIALOG_SCRIPT.new()
	playtime_edit_dialog.save_requested.connect(callbacks["_on_playtime_save_requested"])
	owner.add_child(playtime_edit_dialog)

	var game_remove_confirm = ConfirmationDialog.new()
	game_remove_confirm.title = "移除游戏档案"
	game_remove_confirm.ok_button_text = "移除"
	game_remove_confirm.cancel_button_text = "取消"
	game_remove_confirm.confirmed.connect(callbacks["_on_game_remove_confirmed"])
	owner.add_child(game_remove_confirm)
	return {
		"game_scraper_dialog": game_scraper_dialog,
		"library_scan_dialog": library_scan_dialog,
		"game_manage_menu": game_manage_menu,
		"steam_search_dialog": steam_search_dialog,
		"game_metadata_dialog": game_metadata_dialog,
		"game_launch_dialog": game_launch_dialog,
		"playtime_edit_dialog": playtime_edit_dialog,
		"game_remove_confirm": game_remove_confirm,
	}
