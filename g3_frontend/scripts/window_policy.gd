extends RefCounted

# Consolidated window policies (UI-S7c/e/i/j); preserve original behaviors.

# UI-S7c: Preserve the existing window aspect threshold and minimum height.
# Return the input unchanged when no resize is needed.
static func constrained_size(size: Vector2i, target_aspect: float) -> Vector2i:
	if size.y <= 0:
		return size
	var current_ratio: float = float(size.x) / float(size.y)
	if absf(current_ratio - target_aspect) < 0.005:
		return size
	var new_height: int = int(round(float(size.x) / target_aspect))
	if new_height < 400:
		new_height = 400
	return Vector2i(size.x, new_height)

# UI-S7e: Preserve the existing 1244x700 startup window centering rule.
static func centered_position(screen_size: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(0, (screen_size.x - 1244) / 2),
		maxi(0, (screen_size.y - 700) / 2)
	)

# UI-S7i: Keep the existing window chrome visibility rules for fullscreen modes.
static func apply_chrome_visibility(win: Window, window_chrome: Control) -> void:
	if win == null:
		return
	var mode: Window.Mode = win.mode
	var is_fullscreen: bool = (
		mode == Window.MODE_FULLSCREEN
		or mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	)
	if window_chrome != null:
		window_chrome.visible = not is_fullscreen

# UI-S7j: Preserve the existing borderless and fullscreen/windowed mode rules.
# Deferred window sizing and chrome refresh remain owned by main.gd.
static func apply_mode(mode: String, win: Window) -> void:
	win.borderless = true
	if mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
