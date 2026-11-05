from pathlib import Path

ROOT = Path(__file__).parents[1]
SECTION = (ROOT / "g3_frontend/scripts/game_section.gd").read_text(encoding="utf-8")
DETAIL = (ROOT / "g3_frontend/scripts/game_detail_view.gd").read_text(encoding="utf-8")


def _function(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.index(marker)
    next_func = source.find("\nfunc ", start + len(marker))
    return source[start:] if next_func < 0 else source[start:next_func]


def test_sidebar_detail_entry_waits_for_matching_hero_ready_signal():
    sidebar = _function(SECTION, "_on_sidebar_pressed")
    ready_handler = _function(SECTION, "_on_detail_game_hero_ready")

    assert "game_hero_ready.connect(_on_detail_game_hero_ready)" in SECTION
    assert "signal game_hero_ready(media_key: String, has_hero: bool)" in DETAIL
    assert "prepare_game_media(games[index], true)" in sidebar
    assert "is_game_hero_prepared" in sidebar
    assert "_enter_detail(index, true)" not in sidebar
    assert "media_key != _sidebar_pending_media_key" in ready_handler
    open_pending = _function(SECTION, "_open_pending_sidebar_detail")
    assert "_enter_detail(index)" in open_pending


def test_hero_is_prepared_on_main_thread_and_preserved_for_first_detail_frame():
    worker = _function(DETAIL, "_load_game_media_worker")
    show_game = _function(DETAIL, "show_game")
    hero_ready = _function(DETAIL, "_on_game_hero_image_decoded")

    assert 'call_deferred("_on_game_hero_image_decoded", hero_image, token, key)' in worker
    assert "if hero_first:" in worker
    assert "_prepared_hero_key = key" in hero_ready
    assert "game_hero_ready.emit(key, hero_texture != null)" in hero_ready
    assert "_prepared_hero_texture" in hero_ready
    assert "_prepared_hero_key == _current_media_key" in show_game
    assert "_hero_rect.texture = _prepared_hero_texture" in show_game


def test_grid_click_keeps_its_existing_batch_preload_path():
    grid = _function(SECTION, "_on_grid_pressed")
    detail = _function(DETAIL, "prepare_game_media")

    assert 'call("prepare_game_media", games[index])' in grid
    assert "hero_first: bool = false" in detail
    assert "if hero_first and not _media_hero_first" in detail
