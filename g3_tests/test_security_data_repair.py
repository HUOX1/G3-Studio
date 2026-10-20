"""Regression cases for isolated T03/T04/T05/T07/T08/T09/T10/T12 repairs."""

from pathlib import Path
import sqlite3

import pytest

from g3_core.database import Database
from g3_core.repository import LibraryRepository
from g3_core.services.fontset_store import FontsetStore
from g3_core.services.library_scanner import MovieLibraryScanner
from g3_core.services.media_assets import MediaAssetService


def _repo(tmp_path):
    db = Database(tmp_path / 'library.db')
    db.initialize()
    return LibraryRepository(db)


def _item(repo, item_id, title, media_type='movie', scope='main', source=''):
    with repo.database.connect() as conn:
        conn.execute('''INSERT INTO library_items
          (id, media_type, title, sort_title, source_path, library_scope, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, 'now', 'now')''',
          (item_id, media_type, title, title.casefold(), source, scope))
        if media_type == 'game':
            conn.execute('INSERT INTO games (item_id) VALUES (?)', (item_id,))


def test_rescan_retains_episode_metadata_ids_and_offline_entries(tmp_path):
    repo = _repo(tmp_path)
    root = tmp_path / 'video-library'
    season = root / 'Show' / 'S01'
    season.mkdir(parents=True)
    e1 = season / 'S01E01.mkv'
    e2 = season / 'S01E02.mkv'
    e1.write_bytes(b'1')
    e2.write_bytes(b'2')
    scanner = MovieLibraryScanner(repo)
    assert scanner.scan([str(root)]).added == 1
    series = repo.list_movies()[0]
    item_id = series['id']
    first = repo.get_series_episodes(item_id)
    with repo.database.connect() as conn:
        conn.execute('UPDATE movie_episodes SET title=?, overview=? WHERE id=?',
                     ('Custom E1', 'Detailed synopsis', first[0]['id']))
    scanner.scan([str(root)])
    assert repo.get_series_episodes(item_id)[0]['id'] == first[0]['id']
    assert repo.get_series_episodes(item_id)[0]['title'] == 'Custom E1'
    assert repo.get_series_episodes(item_id)[0]['overview'] == 'Detailed synopsis'
    renamed = season / 'S01E01-renamed.mkv'
    e1.rename(renamed)
    scanner.scan([str(root)])
    after_rename = repo.get_series_episodes(item_id)
    assert len(after_rename) == 2
    assert after_rename[0]['id'] == first[0]['id']
    assert after_rename[0]['title'] == 'Custom E1'
    e2.unlink()
    scanner.scan([str(root)])
    assert len(repo.get_series_episodes(item_id)) == 2
    assert len(repo.list_movies()) == 1
    assert repo.get_movie(item_id)['offline'] == 0


def test_rescan_does_not_overwrite_custom_movie_title_or_cross_scopes(tmp_path):
    repo = _repo(tmp_path)
    root = tmp_path / 'films'
    root.mkdir()
    (root / 'Original.mkv').write_bytes(b'')
    scanner = MovieLibraryScanner(repo)
    scanner.scan([str(root)], 'main')
    main_id = repo.list_movies('main')[0]['id']
    with repo.database.connect() as conn:
        conn.execute('UPDATE library_items SET title=? WHERE id=?', ('Personal name', main_id))
    scanner.scan([str(root)], 'main')
    assert repo.get_movie(main_id)['title'] == 'Personal name'
    scanner.scan([str(root)], 'private')
    assert len(repo.list_movies('main')) == len(repo.list_movies('private')) == 1
    assert repo.list_movies('private')[0]['title'] == 'Original'


def test_movie_covers_are_isolated_and_survive_rename(tmp_path):
    repo = _repo(tmp_path)
    _item(repo, 'main-id', 'Same title', 'movie', 'main')
    _item(repo, 'private-id', 'Same title', 'movie', 'private')
    service = MediaAssetService(repo, tmp_path / 'cache')
    main_cover = tmp_path / 'a.jpg'
    private_cover = tmp_path / 'b.jpg'
    main_cover.write_bytes(b'aaa')
    private_cover.write_bytes(b'bbb')
    a = service.set_movie_cover('main-id', main_cover)
    b = service.set_movie_cover('private-id', private_cover)
    assert a != b and a.read_bytes() == b'aaa' and b.read_bytes() == b'bbb'
    assert service.resolve_movie_cover('main-id') == a
    assert service.resolve_movie_cover('private-id') == b
    with repo.database.connect() as conn:
        conn.execute('UPDATE library_items SET title=? WHERE id=?', ('Renamed', 'main-id'))
    assert service.resolve_movie_cover('main-id') == a


def test_steam_fill_empty_only_and_repeated_scrape(tmp_path):
    repo = _repo(tmp_path)
    _item(repo, 'game-a', 'Title', 'game')
    with repo.database.connect() as conn:
        conn.execute('INSERT INTO game_metadata (item_id, developer, genres) VALUES (?, ?, ?)',
                     ('game-a', 'Manual developer', 'RPG'))
        conn.execute('UPDATE library_items SET description=? WHERE id=?', ('Manual description', 'game-a'))
    for _ in range(2):
        repo.apply_steam_metadata('game-a', steam_appid=123, developer='Steam developer',
                                  publisher='Steam publisher', genres='Action',
                                  description='Steam description', detailed_description='Detailed')
    with repo.database.connect() as conn:
        row = conn.execute('SELECT * FROM game_metadata WHERE item_id=?', ('game-a',)).fetchone()
        desc = conn.execute('SELECT description FROM library_items WHERE id=?', ('game-a',)).fetchone()[0]
    assert row['developer'] == 'Manual developer'
    assert row['publisher'] == 'Steam publisher'
    assert row['genres'] == 'RPG'
    assert row['detailed_description'] == 'Detailed'
    assert desc == 'Manual description'


def test_old_game_database_column_migration_is_idempotent(tmp_path):
    repo = _repo(tmp_path)
    _item(repo, 'g1', 'Old game', 'game')
    with repo.database.connect() as conn:
        conn.execute('ALTER TABLE games DROP COLUMN playtime_edit_count')
        conn.execute('UPDATE games SET playtime_seconds=123 WHERE item_id=?', ('g1',))
    repo.database.initialize()
    repo.database.initialize()
    with repo.database.connect() as conn:
        row = conn.execute('SELECT playtime_seconds, playtime_edit_count FROM games WHERE item_id=?', ('g1',)).fetchone()
    assert (row['playtime_seconds'], row['playtime_edit_count']) == (123, 0)
    assert repo.list_games()[0]['id'] == 'g1'


def test_fontset_games_rename_preserves_scope(tmp_path):
    store = FontsetStore(tmp_path / 'fontsets')
    fs = store.create('Games preset', scope='games')
    renamed = store.rename(fs.id, 'New name', scope='games')
    assert renamed.id == fs.id and renamed.name == 'New name' and renamed.scope == 'games'
    with pytest.raises(ValueError):
        store.rename(fs.id, 'Wrong library', scope='movies')


def test_tmdb_fallback_does_not_reuse_precisely_consumed_episode(tmp_path):
    repo = _repo(tmp_path)
    _item(repo, 'series-a', 'Show', 'series')
    with repo.database.connect() as conn:
        conn.execute('''INSERT INTO movie_episodes (id,item_id,season,episode,display_order,video_path)
                        VALUES ('a','series-a',1,1,0,'a.mkv'),('b','series-a',NULL,NULL,1,'b.mkv')''')
    repo.apply_tmdb_episode_metadata('series-a', {1: {1: {'title': 'TMDB A'}, 2: {'title': 'TMDB B'}}})
    episodes = repo.get_series_episodes('series-a')
    assert [x['title'] for x in episodes] == ['TMDB A', 'TMDB B']


def test_ffmpeg_custom_executable_resolves_ffprobe(tmp_path, monkeypatch):
    repo = _repo(tmp_path)
    service = MediaAssetService(repo, tmp_path / 'cache', ffmpeg_path=str(tmp_path / 'ffmpeg.exe'))
    calls = []
    import subprocess
    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, stdout='12.5')
    monkeypatch.setattr('g3_core.services.media_assets.subprocess.run', fake_run)
    assert service._probe_video_duration(tmp_path / 'dummy.mp4') == 12.5
    assert calls[0][0] == str(tmp_path / 'ffprobe.exe')


def test_game_assets_use_stable_id_and_legacy_rename_copy(tmp_path, monkeypatch):
    from g3_core.backend_app import BackendApplication
    from g3_core.paths import TerminalPaths
    monkeypatch.setenv('LOCALAPPDATA', str(tmp_path))
    paths = TerminalPaths.from_environment().ensure()
    app = BackendApplication(paths, builtin_theme_root=tmp_path / 'builtin')
    app.database.initialize()
    _item(app.repository, 'game-1', 'Old Title', 'game')
    old_dir = paths.covers / 'games' / 'Old Title'
    old_dir.mkdir(parents=True)
    (old_dir / 'cover.jpg').write_bytes(b'oldcover')
    (old_dir / 'backdrop.jpg').write_bytes(b'oldbackdrop')
    app._preserve_game_assets_before_rename(app.repository.get_game('game-1'))
    with app.database.connect() as conn:
        conn.execute('UPDATE library_items SET title=? WHERE id=?', ('New Title', 'game-1'))
    result = app._game_to_dict(app.repository.get_game('game-1'))
    assert str(paths.covers / 'games' / 'game-1') in result['cover']
    assert any(str(paths.covers / 'games' / 'game-1') in path for path in result['backdrop'])
    assert (old_dir / 'cover.jpg').read_bytes() == b'oldcover'
    new_source = tmp_path / 'new.png'
    new_source.write_bytes(b'newcover')
    target = app.media.set_game_cover('game-1', new_source)
    assert target.parent.name == 'game-1'
    assert (old_dir / 'cover.jpg').read_bytes() == b'oldcover'


@pytest.mark.asyncio
async def test_settings_ffmpeg_path_applies_at_start_and_update(tmp_path, monkeypatch):
    import json
    from g3_core.backend_app import BackendApplication
    from g3_core.paths import TerminalPaths
    from g3_core.settings import TerminalSettings
    monkeypatch.setenv('LOCALAPPDATA', str(tmp_path))
    paths = TerminalPaths.from_environment().ensure()
    old = TerminalSettings.default().to_dict()
    old['ffmpeg_path'] = 'original-ffmpeg'
    paths.settings.write_text(json.dumps(old), encoding='utf-8')
    app = BackendApplication(paths, builtin_theme_root=tmp_path / 'builtin')
    app.initialize()
    assert app.media.ffmpeg_path == 'original-ffmpeg'
    await app.handle_command('settings.update', {'ffmpeg_path': 'custom-ffmpeg'})
    assert app.media.ffmpeg_path == 'custom-ffmpeg'
