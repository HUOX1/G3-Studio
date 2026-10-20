from __future__ import annotations

from datetime import datetime, timezone
import json
import uuid

from .database import Database


class LibraryRepository:
	def __init__(self, database: Database) -> None:
		self.database = database

	def apply_tmdb_movie(
		self,
		item_id: str,
		*,
		release_year: str | None = None,
		description: str | None = None,
		genres: str | None = None,
		runtime_minutes: int | None = None,
		vote_average: float | None = None,
		tagline: str | None = None,
		tmdb_id: int | None = None,
	) -> None:
		"""TMDB 资料写库。只填空字段，不覆盖已有内容。"""
		now = datetime.now(timezone.utc).isoformat()
		with self.database.connect() as conn:
			# 确保 game_metadata 有记录
			conn.execute(
				"""
				INSERT INTO game_metadata
					(item_id, developer, publisher, release_year, tags, notes)
				VALUES (?, '', '', NULL, '', '')
				ON CONFLICT(item_id) DO NOTHING
				""",
				(item_id,),
			)

			if release_year:
				conn.execute(
					"""
					UPDATE game_metadata
					SET release_year = ?
					WHERE item_id = ?
					  AND (release_year IS NULL OR CAST(release_year AS TEXT) IN ('', '0'))
					""",
					(str(release_year), item_id),
				)
			if genres:
				conn.execute(
					"""
					UPDATE game_metadata
					SET genres = ?
					WHERE item_id = ? AND (genres IS NULL OR genres = '')
					""",
					(genres, item_id),
				)
			if runtime_minutes and runtime_minutes > 0:
				conn.execute(
					"""
					UPDATE game_metadata
					SET runtime_minutes = ?
					WHERE item_id = ?
					  AND (runtime_minutes IS NULL OR runtime_minutes = 0)
					""",
					(int(runtime_minutes), item_id),
				)
			if vote_average and vote_average > 0:
				conn.execute(
					"""
					UPDATE game_metadata
					SET vote_average = ?
					WHERE item_id = ?
					  AND (vote_average IS NULL OR vote_average = 0)
					""",
					(float(vote_average), item_id),
				)
			if tagline:
				conn.execute(
					"""
					UPDATE game_metadata
					SET tagline = ?
					WHERE item_id = ? AND (tagline IS NULL OR tagline = '')
					""",
					(str(tagline).strip(), item_id),
				)
			if tmdb_id and tmdb_id > 0:
				conn.execute(
					"UPDATE game_metadata SET tmdb_id = ? WHERE item_id = ?",
					(int(tmdb_id), item_id),
				)
			if description:
				conn.execute(
					"""
					UPDATE library_items
					SET description = CASE WHEN description = '' THEN ? ELSE description END,
						updated_at = ?
					WHERE id = ? AND media_type IN ('movie', 'series')
					""",
					(description, now, item_id),
				)

	def apply_tmdb_episode_metadata(
		self,
		item_id: str,
		tmdb_seasons: dict[int, dict[int, dict[str, str]]],
	) -> int:
		"""把 TMDB 每集的 title / overview 填进 movie_episodes（只填空的）。

		tmdb_seasons 结构：
			{season_num: {episode_num: {"title": str, "overview": str}}}

		匹配策略：
		1. 若本地集的 season/episode 都不是 NULL，按 (season, episode) 精确匹配
		2. 匹配不到的，按 display_order 顺序，用 TMDB 展平的数据依次填
		（应对本地无季号结构的情况）
		"""
		flat_entries: list[tuple[tuple[int, int], dict[str, str]]] = []
		for s_num in sorted(tmdb_seasons.keys()):
			ep_map = tmdb_seasons[s_num]
			for e_num in sorted(ep_map.keys()):
				entry = ep_map[e_num]
				flat_entries.append(((int(s_num), int(e_num)), {
					"title": str(entry.get("title", "") or "").strip(),
					"overview": str(entry.get("overview", "") or "").strip(),
				}))

		if not flat_entries:
			return 0

		updated = 0
		with self.database.connect() as conn:
			rows = conn.execute(
				"""
				SELECT id, season, episode, display_order, title, overview
				FROM movie_episodes
				WHERE item_id = ?
				ORDER BY display_order, id
				""",
				(item_id,),
			).fetchall()

			def _fill_row(row, entry: dict[str, str]) -> bool:
				row_id = str(row["id"])
				new_title = str(row["title"] or "").strip()
				new_overview = str(row["overview"] or "").strip()
				changed = False
				if not new_title and entry.get("title"):
					new_title = entry["title"]
					changed = True
				if not new_overview and entry.get("overview"):
					new_overview = entry["overview"]
					changed = True
				if not changed:
					return False
				conn.execute(
					"UPDATE movie_episodes SET title = ?, overview = ? WHERE id = ?",
					(new_title, new_overview, row_id),
				)
				return True

			# 第 1 步：精确匹配
			matched_ids: set[str] = set()
			consumed_keys: set[tuple[int, int]] = set()
			for row in rows:
				row_id = str(row["id"])
				s_val = row["season"]
				e_val = row["episode"]
				if s_val is None or e_val is None:
					continue
				ep_map = tmdb_seasons.get(int(s_val))
				if not ep_map:
					continue
				entry = ep_map.get(int(e_val))
				if not entry:
					continue
				if _fill_row(row, entry):
					updated += 1
				matched_ids.add(row_id)
				consumed_keys.add((int(s_val), int(e_val)))

			# 第 2 步：线性兜底
			remaining_entries = [entry for key, entry in flat_entries if key not in consumed_keys]
			flat_index = 0
			for row in rows:
				row_id = str(row["id"])
				if row_id in matched_ids:
					continue
				if flat_index >= len(remaining_entries):
					break
				entry = remaining_entries[flat_index]
				flat_index += 1
				if _fill_row(row, entry):
					updated += 1

		return updated

	def list_movies(self, scope: str = "main") -> list[dict]:
		with self.database.connect() as conn:
			rows = conn.execute(
				"""
				SELECT li.id, li.title, li.sort_title, li.description,
					   li.offline, li.watched_complete,
					   li.library_scope,
					   COALESCE(gm.developer, '') AS developer,
					   COALESCE(gm.publisher, '') AS publisher,
					   gm.release_year AS release_year,
					   COALESCE(gm.tags, '') AS tags,
					   COALESCE(gm.notes, '') AS notes,
					   COALESCE(gm.genres, '') AS genres,
					   COALESCE(gm.runtime_minutes, 0) AS runtime_minutes,
					   COALESCE(gm.vote_average, 0.0) AS vote_average,
					   COALESCE(gm.tagline, '') AS tagline,
					   COALESCE(gm.tmdb_id, 0) AS tmdb_id
				FROM library_items li
				LEFT JOIN game_metadata gm ON gm.item_id = li.id
				WHERE li.media_type IN ('movie', 'series')
				  AND li.library_scope = ?
				ORDER BY li.sort_title, li.id
				""",
				(scope,),
			).fetchall()
		return [dict(row) for row in rows]

	def get_movie(self, item_id: str) -> dict | None:
		with self.database.connect() as conn:
			row = conn.execute(
				"""
				SELECT li.id, li.title, li.description, li.library_scope,
					   li.offline, li.watched_complete,
					   COALESCE(gm.developer, '') AS developer,
					   COALESCE(gm.publisher, '') AS publisher,
					   gm.release_year AS release_year,
					   COALESCE(gm.tags, '') AS tags,
					   COALESCE(gm.notes, '') AS notes,
					   COALESCE(gm.genres, '') AS genres,
					   COALESCE(gm.runtime_minutes, 0) AS runtime_minutes,
					   COALESCE(gm.vote_average, 0.0) AS vote_average,
					   COALESCE(gm.tagline, '') AS tagline,
					   COALESCE(gm.tmdb_id, 0) AS tmdb_id
				FROM library_items li
				LEFT JOIN game_metadata gm ON gm.item_id = li.id
				WHERE li.media_type IN ('movie', 'series') AND li.id = ?
				""",
				(item_id,),
			).fetchone()
		return dict(row) if row else None

	def get_movie_source_path(self, item_id: str) -> str:
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT source_path FROM library_items WHERE id = ? AND media_type IN ('movie', 'series')",
				(item_id,),
			).fetchone()
		if row is None:
			return ""
		return str(row["source_path"] or "")

	def get_total_seconds(self, item_id: str) -> int:
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT total_seconds FROM library_items WHERE id = ?",
				(item_id,),
			).fetchone()
		return int(row["total_seconds"]) if row else 0

	def set_total_seconds(self, item_id: str, seconds: int) -> None:
		with self.database.connect() as conn:
			conn.execute(
				"UPDATE library_items SET total_seconds = ? WHERE id = ?",
				(int(seconds), item_id),
			)

	def add_watch_seconds(self, item_id: str, seconds: int) -> bool:
		"""累加观看秒数。如果首次跨过 70% 阈值，返回 True。"""
		if seconds <= 0:
			return False
		now = datetime.now(timezone.utc).isoformat()
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT watched_seconds, total_seconds, watched_complete "
				"FROM library_items WHERE id = ?",
				(item_id,),
			).fetchone()
			if row is None:
				return False
			was_complete = bool(row["watched_complete"])
			total = int(row["total_seconds"])
			new_seconds = int(row["watched_seconds"]) + int(seconds)
			now_complete = was_complete
			if (
				total > 0
				and not was_complete
				and new_seconds >= int(total * 0.70)
			):
				now_complete = True
			conn.execute(
				"""
				UPDATE library_items
				SET watched_seconds = ?, watched_complete = ?, updated_at = ?
				WHERE id = ?
				""",
				(new_seconds, 1 if now_complete else 0, now, item_id),
			)
		return (not was_complete) and now_complete

	def find_game_by_video_path(self, video_path: str) -> dict | None:
		"""按 source_path 精确匹配已有游戏。

		游戏的 source_path 存的是 video_path（见 create_game 写入逻辑）。
		"""
		clean_path = str(video_path or "").strip()
		if not clean_path:
			return None
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT id, title, source_path, offline FROM library_items"
				" WHERE media_type = 'game' AND source_path = ?",
				(clean_path,),
			).fetchone()
		if row is None:
			return None
		return dict(row)

	def find_game_by_steam_appid(self, appid: int) -> dict | None:
		"""按 steam_appid 精确匹配已有游戏。"""
		clean_appid = int(appid or 0)
		if clean_appid <= 0:
			return None
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT item_id, steam_appid, source, playtime_seconds"
				" FROM games WHERE steam_appid = ?",
				(clean_appid,),
			).fetchone()
		if row is None:
			return None
		return dict(row)

	def update_steam_playtime(
		self, steam_appid: int, seconds: int, last_played_ts: int
	) -> bool:
		"""用 Steam 的时长刷新游戏记录。

		只更新 source='steam' 的行（不误伤手动添加的游戏），
		且只增不减（避免 Steam 清档 / 换账号把 G3 时长写小）。
		last_played_at 与时长在同一个 UPDATE 里更新，所以只在时长增加时才变。
		返回是否真的更新了。
		"""
		clean_appid = int(steam_appid or 0)
		new_seconds = max(0, int(seconds or 0))
		if clean_appid <= 0 or new_seconds <= 0:
			return False
		ts = int(last_played_ts or 0)
		last_played_iso = (
			datetime.fromtimestamp(ts, timezone.utc).isoformat() if ts > 0 else None
		)
		with self.database.connect() as conn:
			cursor = conn.execute(
				"""
				UPDATE games
				SET playtime_seconds = ?, last_played_at = ?
				WHERE steam_appid = ? AND source = 'steam'
				  AND playtime_seconds < ?
				""",
				(new_seconds, last_played_iso, clean_appid, new_seconds),
			)
			return cursor.rowcount > 0

	def find_game_by_external_id(self, external_id: str, source: str) -> dict | None:
		"""按平台侧外部 ID + 来源匹配已有游戏（GOG gameID / Epic AppName）。"""
		clean_id = str(external_id or "").strip()
		clean_source = str(source or "").strip().lower()
		if not clean_id or not clean_source:
			return None
		with self.database.connect() as conn:
			row = conn.execute(
				"""
				SELECT g.item_id, g.external_id, g.source
				FROM games g
				WHERE g.external_id = ? AND g.source = ?
				""",
				(clean_id, clean_source),
			).fetchone()
		if row is None:
			return None
		return dict(row)

	def find_movie_by_source_path(self, source_path: str, scope: str = "main") -> dict | None:
		"""按 source_path 精确匹配已有电影/剧集（限定在指定库）。"""
		with self.database.connect() as conn:
			row = conn.execute(
				"""
				SELECT li.id, li.title, li.description, li.source_path,
					   li.offline,
					   COALESCE(gm.developer, '') AS developer,
					   COALESCE(gm.publisher, '') AS publisher,
					   gm.release_year AS release_year,
					   COALESCE(gm.tags, '') AS tags,
					   COALESCE(gm.notes, '') AS notes
				FROM library_items li
				LEFT JOIN game_metadata gm ON gm.item_id = li.id
				WHERE li.media_type IN ('movie', 'series')
				  AND li.source_path = ?
				  AND li.library_scope = ?
				""",
				(source_path, scope),
			).fetchone()
		return dict(row) if row else None

	def set_movie_offline(self, item_id: str, offline: bool) -> None:
		with self.database.connect() as conn:
			conn.execute(
				"UPDATE library_items SET offline = ? WHERE id = ?",
				(1 if offline else 0, item_id),
			)

	def update_movie_title_from_scan(self, item_id: str, title: str) -> None:
		clean = title.strip()
		if not clean:
			return
		now = datetime.now(timezone.utc).isoformat()
		with self.database.connect() as conn:
			conn.execute(
				"""
				UPDATE library_items
				SET title = ?, sort_title = ?, updated_at = ?
				WHERE id = ? AND media_type IN ('movie', 'series')
				""",
				(clean, clean.casefold(), now, item_id),
			)

	def list_all_movies_for_scan(self, scope: str = "main") -> list[dict]:
		"""返回指定库所有电影/剧集的 id / source_path / offline。"""
		with self.database.connect() as conn:
			rows = conn.execute(
				"""
				SELECT id, source_path, offline
				FROM library_items
				WHERE media_type IN ('movie', 'series')
				  AND library_scope = ?
				""",
				(scope,),
			).fetchall()
		return [dict(row) for row in rows]

	def create_movie(
		self,
		*,
		title: str,
		source_path: str,
		description: str = "",
		release_year: str | None = None,
		scope: str = "main",
	) -> dict:
		clean_title = title.strip()
		if not clean_title:
			raise ValueError("title is required")
		item_id = str(uuid.uuid4())
		now = datetime.now(timezone.utc).isoformat()
		sort_title = clean_title.casefold()
		with self.database.connect() as conn:
			conn.execute(
				"""
				INSERT INTO library_items
					(id, media_type, title, sort_title, description,
					 source_path, library_scope, created_at, updated_at)
				VALUES (?, 'movie', ?, ?, ?, ?, ?, ?, ?)
				""",
				(item_id, clean_title, sort_title,
				 description.strip(), source_path.strip(), scope, now, now),
			)
			conn.execute(
				"""
				INSERT INTO game_metadata
					(item_id, developer, publisher, release_year, tags, notes)
				VALUES (?, '', '', ?, '', '')
				""",
				(item_id, str(release_year).strip() if release_year else None),
			)
		movie = self.get_movie(item_id)
		if movie is None:
			raise RuntimeError("created movie could not be reloaded")
		return movie

	def create_game(
		self,
		*,
		title: str,
		english_name: str = "",
		developer: str = "",
		publisher: str = "",
		genres: str = "",
		tags: str = "",		
		platform: str = "",
		video_path: str = "",
		description: str = "",
		release_year: str | None = None,
		profile_type: str = "direct",
		launch_exe: str = "",
		launch_args: str = "",
		working_directory: str = "",
		content_path: str = "",
		monitor_exe: str = "",
		run_as_admin: bool = False,
		source: str = "manual",
		steam_appid: int = 0,
		psn_playtime_seconds: int = 0,		
		external_id: str = "",
		namespace_id: str = "",
		artifact_id: str = "",
	) -> dict:
		clean_title = title.strip()
		if not clean_title:
			raise ValueError("title is required")
		p_type = profile_type.strip().lower()
		if p_type not in ("direct", "launcher", "emulator"):
			p_type = "direct"
		item_id = str(uuid.uuid4())
		now = datetime.now(timezone.utc).isoformat()
		sort_title = clean_title.casefold()
		year_text = None
		if release_year:
			text = str(release_year).strip()
			if text and text not in ("0", "None"):
				year_text = text
		with self.database.connect() as conn:
			conn.execute(
				"""
				INSERT INTO library_items
					(id, media_type, title, sort_title, description,
					 source_path, created_at, updated_at)
				VALUES (?, 'game', ?, ?, ?, ?, ?, ?)
				""",
				(item_id, clean_title, sort_title, description.strip(),
				 video_path.strip(), now, now),
			)
			conn.execute(
				"""
			INSERT INTO games
					(item_id, platform, english_name, profile_type, launch_exe, launch_args,
					 working_directory, content_path, monitor_exe, run_as_admin,
					 source, steam_appid, playtime_source, external_id,
					 namespace_id, artifact_id, psn_playtime_seconds)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
				""",
				(
					item_id, platform.strip(), str(english_name or "").strip(), p_type,
					launch_exe.strip(), launch_args.strip(),
					working_directory.strip(), content_path.strip(),
					monitor_exe.strip(),
					1 if run_as_admin else 0,
					source.strip().lower() or "manual",
					int(steam_appid or 0),
					# Steam 游戏的时长来自 Steam 本地文件，不是 G3 自己计时
					"steam" if source.strip().lower() == "steam" else "g3",
					str(external_id or "").strip(),
					str(namespace_id or "").strip(),
					str(artifact_id or "").strip(),
					int(psn_playtime_seconds or 0),
				),
			)
			conn.execute(
				"""
				INSERT INTO game_metadata
					(item_id, developer, publisher, release_year, tags, notes, genres)
				VALUES (?, ?, ?, ?, ?, '', ?)
				""",
				(
					item_id,
					str(developer or "").strip(),
					str(publisher or "").strip(),
					year_text,
					str(tags or "").strip(),
					str(genres or "").strip(),
				),
			)
		return self.get_game(item_id)

	def update_game_play_stats(self, item_id: str, seconds: int, ended_at: datetime) -> None:
		now_iso = ended_at.astimezone(timezone.utc).isoformat()
		with self.database.connect() as conn:
			conn.execute(
				"""
				UPDATE games
				SET playtime_seconds = playtime_seconds + ?, last_played_at = ?
				WHERE item_id = ?
				""",
				(max(0, int(seconds)), now_iso, item_id),
			)

	def set_game_playtime(self, item_id: str, seconds: int) -> bool:
		"""手动设置游玩时长。返回 True 表示成功；False 表示已用完修改次数或条目不存在。"""
		if seconds < 0:
			raise ValueError("seconds must be >= 0")
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT playtime_edit_count FROM games WHERE item_id = ?",
				(item_id,),
			).fetchone()
			if row is None:
				return False
			count = int(row["playtime_edit_count"])
			if count >= 2:
				return False
			conn.execute(
				"""
				UPDATE games
				SET playtime_seconds = ?, playtime_edit_count = ?
				WHERE item_id = ?
				""",
				(int(seconds), count + 1, item_id),
			)
		return True

	def set_game_sgdb_id(self, item_id: str, sgdb_id: int) -> None:
		with self.database.connect() as conn:
			conn.execute(
				"UPDATE games SET sgdb_id = ? WHERE item_id = ?",
				(int(sgdb_id), item_id),
			)

	def apply_steam_metadata(
		self,
		item_id: str,
		*,
		steam_appid: int,
		release_date: str = "",
		screenshots_json: str = "",
		metacritic: int = 0,
		developer: str = "",
		publisher: str = "",
		genres: str = "",
		description: str = "",
		release_year: str | None = None,
		detailed_description: str = "",
		videos_json: str = "",
		content_blocks_json: str = "",
	) -> None:
		"""把 Steam 刮削的数据写库。"""
		now = datetime.now(timezone.utc).isoformat()
		with self.database.connect() as conn:
			# 更新 games 表的 steam_appid
			conn.execute(
				"UPDATE games SET steam_appid = ? WHERE item_id = ?",
				(int(steam_appid), item_id),
			)
			# 确保 game_metadata 有记录
			conn.execute(
				"""
				INSERT INTO game_metadata
					(item_id, developer, publisher, release_year, tags, notes)
				VALUES (?, '', '', NULL, '', '')
				ON CONFLICT(item_id) DO NOTHING
				""",
				(item_id,),
			)
			# developer / publisher / genres：有值才写
			if developer:
				conn.execute(
					"UPDATE game_metadata SET developer = ? WHERE item_id = ? AND (developer IS NULL OR developer = '')",
					(developer, item_id),
				)
			if publisher:
				conn.execute(
					"UPDATE game_metadata SET publisher = ? WHERE item_id = ? AND (publisher IS NULL OR publisher = '')",
					(publisher, item_id),
				)
			if genres:
				conn.execute(
					"UPDATE game_metadata SET genres = ? WHERE item_id = ? AND (genres IS NULL OR genres = '')",
					(genres, item_id),
				)
			if release_year:
				conn.execute(
					"UPDATE game_metadata SET release_year = ? WHERE item_id = ? AND (release_year IS NULL OR release_year = '')",
					(str(release_year), item_id),
				)
			if release_date:
				conn.execute(
					"UPDATE game_metadata SET release_date = ? WHERE item_id = ? AND (release_date IS NULL OR release_date = '')",
					(release_date, item_id),
				)
			if screenshots_json:
				conn.execute(
					"UPDATE game_metadata SET screenshots_json = ? WHERE item_id = ? AND (screenshots_json IS NULL OR screenshots_json = '')",
					(screenshots_json, item_id),
				)
			if metacritic > 0:
				conn.execute(
					"UPDATE game_metadata SET metacritic = ? WHERE item_id = ? AND (metacritic IS NULL OR metacritic = 0)",
					(int(metacritic), item_id),
				)
			if description:
				conn.execute(
					"""
					UPDATE library_items
					SET description = ?, updated_at = ?
					WHERE id = ? AND media_type = 'game' AND (description IS NULL OR description = '')
					""",
					(description, now, item_id),
				)
			if detailed_description:
				conn.execute(
					"UPDATE game_metadata SET detailed_description = ? WHERE item_id = ? AND (detailed_description IS NULL OR detailed_description = '')",
					(detailed_description, item_id),
				)
			if videos_json:
				conn.execute(
					"UPDATE game_metadata SET videos_json = ? WHERE item_id = ? AND (videos_json IS NULL OR videos_json = '')",
					(videos_json, item_id),
				)
			if content_blocks_json:
				conn.execute(
					"UPDATE game_metadata SET content_blocks = ? WHERE item_id = ? AND (content_blocks IS NULL OR content_blocks = '')",
					(content_blocks_json, item_id),
				)

	def list_games(self) -> list[dict]:
		with self.database.connect() as conn:
			rows = conn.execute(self._game_select_sql() + " ORDER BY li.sort_title, li.id").fetchall()
		return [dict(row) for row in rows]

	@staticmethod
	def _game_select_sql(where_clause: str = "") -> str:
		return f"""
			SELECT li.id, li.title, li.sort_title, li.description,
				   li.source_path, li.offline,
				   COALESCE(g.platform, '') AS platform,
				   COALESCE(g.english_name, '') AS english_name,
				   COALESCE(g.profile_type, 'direct') AS profile_type,
				   COALESCE(g.launch_exe, '') AS launch_exe,
				   COALESCE(g.launch_args, '') AS launch_args,
				   COALESCE(g.working_directory, '') AS working_directory,
				   COALESCE(g.content_path, '') AS content_path,
				   COALESCE(g.monitor_exe, '') AS monitor_exe,
				   COALESCE(g.wait_timeout_s, 300) AS wait_timeout_s,
				   COALESCE(g.run_as_admin, 0) AS run_as_admin,
				   COALESCE(g.playtime_seconds, 0) AS playtime_seconds,
				   COALESCE(g.playtime_edit_count, 0) AS playtime_edit_count,
				   g.last_played_at AS last_played_at,
				   COALESCE(g.sgdb_id, 0) AS sgdb_id,
				   COALESCE(g.steam_appid, 0) AS steam_appid,
				   COALESCE(gm.developer, '') AS developer,
				   COALESCE(gm.publisher, '') AS publisher,
				   gm.release_year AS release_year,
				   COALESCE(gm.tags, '') AS tags,
				   COALESCE(gm.notes, '') AS notes,
				   COALESCE(gm.release_date, '') AS release_date,
				   COALESCE(gm.screenshots_json, '') AS screenshots_json,
				   COALESCE(gm.metacritic, 0) AS metacritic,
				   COALESCE(gm.genres, '') AS genres,
				   COALESCE(gm.detailed_description, '') AS detailed_description,
				   COALESCE(gm.videos_json, '') AS videos_json,
				   COALESCE(gm.content_blocks, '') AS content_blocks,
				   COALESCE(g.source, 'manual') AS source,
				   COALESCE(g.playtime_source, 'g3') AS playtime_source,
				   COALESCE(g.external_id, '') AS external_id,
				   COALESCE(g.namespace_id, '') AS namespace_id,
				   COALESCE(g.artifact_id, '') AS artifact_id,
				   COALESCE(g.psn_playtime_seconds, 0) AS psn_playtime_seconds
			FROM library_items li
			LEFT JOIN games g ON g.item_id = li.id
			LEFT JOIN game_metadata gm ON gm.item_id = li.id
			WHERE li.media_type = 'game' {where_clause}
		"""

	def get_game(self, item_id: str) -> dict | None:
		with self.database.connect() as conn:
			row = conn.execute(
				self._game_select_sql("AND li.id = ?"),
				(item_id,),
			).fetchone()
		return dict(row) if row else None

	def remove_game(self, item_id: str) -> bool:
		"""移除游戏档案。不触碰游戏本体或存档。"""
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT media_type FROM library_items WHERE id = ?",
				(item_id,),
			).fetchone()
			if row is None or str(row["media_type"]) != "game":
				return False
			conn.execute("DELETE FROM library_items WHERE id = ?", (item_id,))
		return True

	def update_game_metadata(
		self,
		item_id: str,
		*,
		title: str,
		platform: str = "",
		english_name: str = "",
		description: str = "",
		developer: str = "",
		publisher: str = "",
		release_year: str | None = None,
		tags: str = "",
		notes: str = "",
		genres: str = "",		
	) -> dict:
		clean_title = str(title).strip()
		if not clean_title:
			raise ValueError("title is required")
		year = None
		if release_year not in (None, "", 0, "0"):
			text = str(release_year).strip()
			if text and text != "None":
				year = text
		now = datetime.now(timezone.utc).isoformat()
		with self.database.connect() as conn:
			cursor = conn.execute(
				"""
				UPDATE library_items
				SET title = ?, sort_title = ?, description = ?, updated_at = ?
				WHERE id = ? AND media_type = 'game'
				""",
				(clean_title, clean_title.casefold(),
				 str(description).strip(), now, item_id),
			)
			if cursor.rowcount != 1:
				raise KeyError(item_id)
			conn.execute(
				"UPDATE games SET platform = ?, english_name = ? WHERE item_id = ?",
				(str(platform).strip(), str(english_name or "").strip(), item_id),
			)
			conn.execute(
				"""
				INSERT INTO game_metadata
					(item_id, developer, publisher, release_year, tags, notes, genres)
				VALUES (?, ?, ?, ?, ?, ?, ?)
				ON CONFLICT(item_id) DO UPDATE SET
					developer = excluded.developer,
					publisher = excluded.publisher,
					release_year = excluded.release_year,
					tags = excluded.tags,
					notes = excluded.notes,
					genres = CASE
						WHEN excluded.genres = '' THEN game_metadata.genres
						ELSE excluded.genres
					END
				""",
				(item_id, str(developer).strip(), str(publisher).strip(),
				 year, str(tags).strip(), str(notes).strip(), str(genres).strip()),
			)
		game = self.get_game(item_id)
		if game is None:
			raise KeyError(item_id)
		return game

	def update_game_launch_profile(
		self,
		item_id: str,
		*,
		profile_type: str = "direct",
		launch_exe: str = "",
		launch_args: str = "",
		working_directory: str = "",
		content_path: str = "",
		monitor_exe: str = "",
		run_as_admin: bool = False,
	) -> dict:
		p_type = str(profile_type).strip().lower()
		if p_type not in ("direct", "launcher", "emulator"):
			p_type = "direct"
		now = datetime.now(timezone.utc).isoformat()
		with self.database.connect() as conn:
			cursor = conn.execute(
				"""
				UPDATE games
				SET profile_type = ?, launch_exe = ?, launch_args = ?,
					working_directory = ?, content_path = ?, monitor_exe = ?,
					run_as_admin = ?
				WHERE item_id = ?
				""",
				(
					p_type,
					str(launch_exe).strip(),
					str(launch_args).strip(),
					str(working_directory).strip(),
					str(content_path).strip(),
					str(monitor_exe).strip(),
					1 if run_as_admin else 0,
					item_id,
				),
			)
			if cursor.rowcount != 1:
				raise KeyError(item_id)
			conn.execute(
				"UPDATE library_items SET updated_at = ? WHERE id = ?",
				(now, item_id),
			)
		game = self.get_game(item_id)
		if game is None:
			raise KeyError(item_id)
		return game

	def create_series_with_episodes(
		self,
		title: str,
		episodes: list[dict],
		platform: str = "",
		scope: str = "main",
	) -> dict:
		clean_title = title.strip()
		if not clean_title:
			raise ValueError("title is required")
		if not episodes:
			raise ValueError("episodes is required")

		item_id = str(uuid.uuid4())
		now = datetime.now(timezone.utc).isoformat()
		sort_title = clean_title.casefold()
		primary_video = episodes[0]["video_path"]

		with self.database.connect() as conn:
			conn.execute(
				"""
				INSERT INTO library_items
					(id, media_type, title, sort_title, description,
					 source_path, library_scope, created_at, updated_at)
				VALUES (?, 'series', ?, ?, '', ?, ?, ?, ?)
				""",
				(item_id, clean_title, sort_title, primary_video, scope, now, now),
			)
			for ep in episodes:
				conn.execute(
					"""
					INSERT INTO movie_episodes
						(id, item_id, season, episode, display_order, video_path, title)
					VALUES (?, ?, ?, ?, ?, ?, ?)
					""",
					(
						str(uuid.uuid4()),
						item_id,
						ep.get("season"),
						ep.get("episode"),
						int(ep.get("display_order", 0)),
						str(ep["video_path"]),
						str(ep.get("title", "")),
					),
				)
		movie = self.get_movie(item_id)
		if movie is None:
			raise RuntimeError("created series could not be reloaded")
		return movie

	def get_series_episodes(self, item_id: str) -> list[dict]:
		with self.database.connect() as conn:
			rows = conn.execute(
				"""
				SELECT id, item_id, season, episode, display_order,
					   video_path, title, overview
				FROM movie_episodes
				WHERE item_id = ?
				ORDER BY display_order, id
				""",
				(item_id,),
			).fetchall()
		return [dict(row) for row in rows]

	def find_series_by_episode_paths(self, video_paths: list[str], scope: str = "main") -> dict | None:
		"""Locate an existing series when its first video changed after a rescan."""
		if not video_paths:
			return None
		with self.database.connect() as conn:
			marks = ", ".join("?" for _ in video_paths)
			rows = conn.execute(
				f"""SELECT DISTINCT li.id, li.title FROM library_items li
				JOIN movie_episodes ep ON ep.item_id = li.id
				WHERE li.media_type = 'series' AND li.library_scope = ?
				AND ep.video_path IN ({marks})""",
				(scope, *video_paths),
			).fetchall()
		# Ambiguous matches must not link two series together.
		return dict(rows[0]) if len(rows) == 1 else None

	def replace_series_episodes(self, item_id: str, episodes: list[dict]) -> None:
		"""Rescan without discarding human/TMDB metadata or absent-file entries.

		Prefer exact normalized video path. Only match renames by unique season/episode
		numbers; ambiguous matches are inserted instead of overwriting old records.
		Old missing files remain associated until an explicit user removal.
		"""
		now = datetime.now(timezone.utc).isoformat()
		with self.database.connect() as conn:
			previous = conn.execute(
				"SELECT id, video_path, season, episode FROM movie_episodes WHERE item_id = ?",
				(item_id,),
			).fetchall()
			by_path = {str(row["video_path"]).replace("\\", "/"): row for row in previous}
			by_numbers: dict[tuple[int, int], list] = {}
			for row in previous:
				if row["season"] is not None and row["episode"] is not None:
					by_numbers.setdefault((int(row["season"]), int(row["episode"])), []).append(row)
			used: set[str] = set()
			for ep in episodes:
				path = str(ep["video_path"]).replace("\\", "/")
				row = by_path.get(path)
				season, episode = ep.get("season"), ep.get("episode")
				if row is None and season is not None and episode is not None:
					candidates = [r for r in by_numbers.get((int(season), int(episode)), [])
					              if str(r["id"]) not in used]
					if len(candidates) == 1:
						row = candidates[0]
				if row is not None and str(row["id"]) not in used:
					used.add(str(row["id"]))
					conn.execute(
						"""UPDATE movie_episodes
						SET season = ?, episode = ?, display_order = ?, video_path = ?
						WHERE id = ? AND item_id = ?""",
						(season, episode, int(ep.get("display_order", 0)), path, row["id"], item_id),
					)
				else:
					conn.execute(
						"""INSERT INTO movie_episodes
						(id, item_id, season, episode, display_order, video_path, title)
						VALUES (?, ?, ?, ?, ?, ?, ?)""",
						(str(uuid.uuid4()), item_id, season, episode,
						 int(ep.get("display_order", 0)), path, str(ep.get("title", ""))),
						)
			if episodes:
				conn.execute(
					"UPDATE library_items SET source_path = ?, updated_at = ? WHERE id = ? AND media_type = 'series'",
					(str(episodes[0]["video_path"]).replace("\\", "/"), now, item_id),
				)

	def update_movie_metadata(
		self,
		item_id: str,
		*,
		title: str,
		release_year: str | int | None = None,
		description: str = "",
		tagline: str = "",
	) -> dict:
		clean_title = str(title).strip()
		if not clean_title:
			raise ValueError("title is required")
		year = None
		if release_year not in (None, "", 0, "0"):
			text = str(release_year).strip()
			if text and text != "None":
				year = text
		now = datetime.now(timezone.utc).isoformat()
		with self.database.connect() as conn:
			cursor = conn.execute(
				"""
				UPDATE library_items
				SET title = ?, sort_title = ?, description = ?, updated_at = ?
				WHERE id = ? AND media_type IN ('movie', 'series')
				""",
				(clean_title, clean_title.casefold(),
				 str(description).strip(), now, item_id),
			)
			if cursor.rowcount != 1:
				raise KeyError(item_id)
			conn.execute(
				"""
				INSERT INTO game_metadata
					(item_id, developer, publisher, release_year, tags, notes, tagline)
				VALUES (?, '', '', ?, '', '', ?)
				ON CONFLICT(item_id) DO UPDATE SET
					release_year = excluded.release_year,
					tagline = excluded.tagline
				""",
				(item_id, year, str(tagline).strip()),
			)
		movie = self.get_movie(item_id)
		if movie is None:
			raise KeyError(item_id)
		return movie

	def remove_movie(self, item_id: str) -> bool:
		"""移除电影/剧集档案。不触碰视频文件、封面或外部资源。"""
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT media_type FROM library_items WHERE id = ?",
				(item_id,),
			).fetchone()
			if row is None or str(row["media_type"]) not in ("movie", "series"):
				return False
			conn.execute("DELETE FROM library_items WHERE id = ?", (item_id,))
		return True

	def get_state(self) -> dict[str, object]:
		with self.database.connect() as conn:
			rows = conn.execute("SELECT key, value_json FROM terminal_state ORDER BY key").fetchall()
		return {str(row["key"]): json.loads(str(row["value_json"])) for row in rows}

	def update_state(self, values: dict[str, object]) -> None:
		with self.database.connect() as conn:
			for key, value in values.items():
				conn.execute(
					"""
					INSERT INTO terminal_state (key, value_json) VALUES (?, ?)
					ON CONFLICT(key) DO UPDATE SET value_json = excluded.value_json
					""",
					(str(key), json.dumps(value, ensure_ascii=False)),
				)

	# ------------------------------------------------------------------
	# 模拟器配置
	# ------------------------------------------------------------------

	EMULATOR_COLUMNS = (
		"id", "name", "executable", "working_dir", "default_args",
		"content_placeholder", "scan_dirs", "platform_tag", "icon_path",
	)

	@classmethod
	def _emulator_insert_sql(cls) -> str:
		columns = ", ".join(cls.EMULATOR_COLUMNS)
		placeholders = ", ".join("?" for _ in cls.EMULATOR_COLUMNS)
		return f"INSERT INTO emulators ({columns}) VALUES ({placeholders})"

	@classmethod
	def _emulator_update_sql(cls) -> str:
		assignments = ", ".join(
			f"{column} = ?" for column in cls.EMULATOR_COLUMNS if column != "id"
		)
		return f"UPDATE emulators SET {assignments} WHERE id = ?"

	@staticmethod
	def _emulator_path(value: object) -> str:
		return str(value or "").strip().replace("\\", "/")

	@staticmethod
	def _normalize_scan_dirs(value: object) -> list[str]:
		"""scan_dirs 允许传数组或 JSON 字符串，统一成去重后的路径数组。"""
		raw: object = value
		if isinstance(raw, str):
			text = raw.strip()
			if not text:
				return []
			try:
				raw = json.loads(text)
			except json.JSONDecodeError:
				return []
		if not isinstance(raw, (list, tuple)):
			return []
		result: list[str] = []
		for entry in raw:
			path = str(entry or "").strip().replace("\\", "/")
			if path and path not in result:
				result.append(path)
		return result

	def _emulator_row_to_dict(self, row) -> dict:
		result: dict[str, object] = {}
		for column in self.EMULATOR_COLUMNS:
			result[column] = row[column]
		result["scan_dirs"] = self._normalize_scan_dirs(row["scan_dirs"])
		return result

	def list_emulators(self) -> list[dict]:
		with self.database.connect() as conn:
			rows = conn.execute(
				"SELECT * FROM emulators ORDER BY name COLLATE NOCASE, id"
			).fetchall()
		return [self._emulator_row_to_dict(row) for row in rows]

	def get_emulator(self, emulator_id: str) -> dict | None:
		with self.database.connect() as conn:
			row = conn.execute(
				"SELECT * FROM emulators WHERE id = ?",
				(str(emulator_id),),
			).fetchone()
		if row is None:
			return None
		return self._emulator_row_to_dict(row)

	def save_emulator(
		self,
		*,
		emulator_id: str = "",
		name: str,
		executable: str = "",
		working_dir: str = "",
		default_args: str = "",
		content_placeholder: str = "{content}",
		scan_dirs: object = None,
		platform_tag: str = "",
		icon_path: str = "",
	) -> dict:
		"""新建（emulator_id 为空）或编辑模拟器配置。"""
		clean_name = str(name or "").strip()
		if not clean_name:
			raise ValueError("name is required")
		clean_id = str(emulator_id or "").strip() or str(uuid.uuid4())
		placeholder = str(content_placeholder or "").strip() or "{content}"
		scan_dirs_json = json.dumps(
			self._normalize_scan_dirs(scan_dirs), ensure_ascii=False
		)
		values = (
			clean_name,
			self._emulator_path(executable),
			self._emulator_path(working_dir),
			str(default_args or "").strip(),
			placeholder,
			scan_dirs_json,
			str(platform_tag or "").strip(),
			self._emulator_path(icon_path),
		)
		with self.database.connect() as conn:
			updated = conn.execute(
				self._emulator_update_sql(),
				(*values, clean_id),
			).rowcount
			if updated != 1:
				conn.execute(
					self._emulator_insert_sql(),
					(clean_id, *values),
				)
		emulator = self.get_emulator(clean_id)
		if emulator is None:
			raise KeyError(clean_id)
		return emulator

	def delete_emulator(self, emulator_id: str) -> bool:
		clean_id = str(emulator_id or "").strip()
		if not clean_id:
			return False
		with self.database.connect() as conn:
			cursor = conn.execute("DELETE FROM emulators WHERE id = ?", (clean_id,))
			return cursor.rowcount > 0