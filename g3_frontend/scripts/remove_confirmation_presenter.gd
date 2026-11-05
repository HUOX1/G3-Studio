extends RefCounted

# UI-S6d: presentation only. Pending IDs, backend removal and callbacks remain in main.gd.
func movie_remove_text(title: String) -> String:
	return ("确定从 G3 中移除《%s》的档案吗？\n\n"
		+ "不会删除视频文件、封面图片或其他本地资源。") % title

func game_remove_text(title: String) -> String:
	return ("确定从 G3 中移除《%s》的档案吗？\n\n"
		+ "不会删除游戏本体、封面图片、媒体素材或存档。") % title

func show_movie_remove(dialog: ConfirmationDialog, title: String) -> void:
	dialog.dialog_text = movie_remove_text(title)
	dialog.popup_centered()

func show_game_remove(dialog: ConfirmationDialog, title: String) -> void:
	dialog.dialog_text = game_remove_text(title)
	dialog.popup_centered()
