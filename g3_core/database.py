
from __future__ import annotations

import sqlite3
from pathlib import Path


class Database:
	def __init__(self, path: Path) -> None:
		self.path = Path(path)

	def connect(self) -> sqlite3.Connection:
		self.path.parent.mkdir(parents=True, exist_ok=True)
		conn = sqlite3.connect(self.path)
		conn.row_factory = sqlite3.Row
		conn.execute("PRAGMA foreign_keys = ON")
		return conn

	def initialize(self) -> None:
		schema_path = Path(__file__).with_name("schema.sql")
		with self.connect() as conn:
			conn.executescript(schema_path.read_text(encoding="utf-8"))
			self._migrate(conn)

	def _migrate(self, conn: sqlite3.Connection) -> None:
		"""对已存在的数据库做增量迁移。"""
		cols = {
			str(row["name"])
			for row in conn.execute("PRAGMA table_info(library_items)").fetchall()
		}
		if "offline" not in cols:
			conn.execute(
				"ALTER TABLE library_items ADD COLUMN offline INTEGER NOT NULL DEFAULT 0"
			)
		if "library_scope" not in cols:
			conn.execute(
				"ALTER TABLE library_items ADD COLUMN library_scope TEXT NOT NULL DEFAULT 'main'"
			)

		existing_tables = {
			str(row["name"])
			for row in conn.execute(
				"SELECT name FROM sqlite_master WHERE type='table'"
			).fetchall()
		}
		# games 表结构升级
		if "games" in existing_tables:
			game_cols = {
				str(row["name"])
				for row in conn.execute("PRAGMA table_info(games)").fetchall()
			}
			# 老版（只有 item_id + platform）→ 补列
			if "profile_type" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN profile_type TEXT NOT NULL DEFAULT 'direct'")
			if "launch_exe" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN launch_exe TEXT NOT NULL DEFAULT ''")
			if "launch_args" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN launch_args TEXT NOT NULL DEFAULT ''")
			if "working_directory" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN working_directory TEXT NOT NULL DEFAULT ''")
			if "content_path" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN content_path TEXT NOT NULL DEFAULT ''")
			if "monitor_exe" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN monitor_exe TEXT NOT NULL DEFAULT ''")
			if "wait_timeout_s" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN wait_timeout_s INTEGER NOT NULL DEFAULT 300")
			if "run_as_admin" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN run_as_admin INTEGER NOT NULL DEFAULT 0")
			if "playtime_seconds" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN playtime_seconds INTEGER NOT NULL DEFAULT 0")
			if "last_played_at" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN last_played_at TEXT")
			if "sgdb_id" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN sgdb_id INTEGER NOT NULL DEFAULT 0")
			if "steam_appid" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN steam_appid INTEGER NOT NULL DEFAULT 0")
			# 游戏来源（manual / steam）与时长来源（g3 / steam）
			if "source" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'")
			if "playtime_source" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN playtime_source TEXT NOT NULL DEFAULT 'g3'")
			# 平台侧的外部 ID（GOG gameID / Epic AppName）
			if "external_id" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN external_id TEXT NOT NULL DEFAULT ''")
			# Epic 启动 URL 需要的三元组附加字段
			if "namespace_id" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN namespace_id TEXT NOT NULL DEFAULT ''")
			if "artifact_id" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN artifact_id TEXT NOT NULL DEFAULT ''")
			# 手动修改游玩时长的次数（上限 2 次，达上限后菜单项隐藏）
			if "playtime_edit_count" not in game_cols:
				conn.execute("ALTER TABLE games ADD COLUMN playtime_edit_count INTEGER NOT NULL DEFAULT 0")
			if "english_name" not in game_cols:
				conn.execute(
					"ALTER TABLE games ADD COLUMN english_name TEXT NOT NULL DEFAULT ''"
				)
			if "psn_playtime_seconds" not in game_cols:
				conn.execute(
					"ALTER TABLE games ADD COLUMN psn_playtime_seconds INTEGER NOT NULL DEFAULT 0"
				)
		if "games" not in existing_tables:
			conn.execute(
				"""
				CREATE TABLE games (
					item_id TEXT PRIMARY KEY REFERENCES library_items(id) ON DELETE CASCADE,
					platform TEXT NOT NULL DEFAULT ''
				)
				"""
			)
		if "movie_episodes" not in existing_tables:
			conn.execute(
				"""
				CREATE TABLE movie_episodes (
					id TEXT PRIMARY KEY,
					item_id TEXT NOT NULL REFERENCES library_items(id) ON DELETE CASCADE,
					season INTEGER,
					episode INTEGER,
					display_order INTEGER NOT NULL DEFAULT 0,
					video_path TEXT NOT NULL,
					title TEXT NOT NULL DEFAULT ''
				)
				"""
			)
			conn.execute(
				"""
				CREATE INDEX idx_movie_episodes_item
				ON movie_episodes(item_id, display_order)
				"""
			)
		# movie_episodes 加 overview 列（每集简介）
		episode_cols = {
			str(row["name"])
			for row in conn.execute("PRAGMA table_info(movie_episodes)").fetchall()
		}
		if "overview" not in episode_cols:
			conn.execute(
				"ALTER TABLE movie_episodes ADD COLUMN overview TEXT NOT NULL DEFAULT ''"
			)
		# game_metadata 加 TMDB 元数据列
		gm_cols = {
			str(row["name"])
			for row in conn.execute("PRAGMA table_info(game_metadata)").fetchall()
		}
		if "genres" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN genres TEXT NOT NULL DEFAULT ''"
			)
		if "runtime_minutes" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN runtime_minutes INTEGER NOT NULL DEFAULT 0"
			)
		if "vote_average" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN vote_average REAL NOT NULL DEFAULT 0.0"
			)
		if "tagline" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN tagline TEXT NOT NULL DEFAULT ''"
			)
		if "tmdb_id" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN tmdb_id INTEGER NOT NULL DEFAULT 0"
			)
		if "release_date" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN release_date TEXT NOT NULL DEFAULT ''"
			)
		if "screenshots_json" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN screenshots_json TEXT NOT NULL DEFAULT ''"
			)
		if "metacritic" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN metacritic INTEGER NOT NULL DEFAULT 0"
			)
		if "detailed_description" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN detailed_description TEXT NOT NULL DEFAULT ''"
			)
		if "videos_json" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN videos_json TEXT NOT NULL DEFAULT ''"
			)
		if "content_blocks" not in gm_cols:
			conn.execute(
				"ALTER TABLE game_metadata ADD COLUMN content_blocks TEXT NOT NULL DEFAULT ''"
			)
		# v0.6.5：library_items 加观看痕迹三列
		li_cols = {
			str(row["name"])
			for row in conn.execute("PRAGMA table_info(library_items)").fetchall()
		}
		if "watched_seconds" not in li_cols:
			conn.execute(
				"ALTER TABLE library_items ADD COLUMN watched_seconds INTEGER NOT NULL DEFAULT 0"
			)
		if "total_seconds" not in li_cols:
			conn.execute(
				"ALTER TABLE library_items ADD COLUMN total_seconds INTEGER NOT NULL DEFAULT 0"
			)
		if "watched_complete" not in li_cols:
			conn.execute(
				"ALTER TABLE library_items ADD COLUMN watched_complete INTEGER NOT NULL DEFAULT 0"
			)
		# 模拟器配置表（v0.6.6）。老库启动时自动建表。
		if "emulators" not in existing_tables:
			conn.execute(
				"""
				CREATE TABLE IF NOT EXISTS emulators (
					id TEXT PRIMARY KEY,
					name TEXT NOT NULL DEFAULT '',
					executable TEXT NOT NULL DEFAULT '',
					working_dir TEXT NOT NULL DEFAULT '',
					default_args TEXT NOT NULL DEFAULT '',
					content_placeholder TEXT NOT NULL DEFAULT '{content}',
					scan_dirs TEXT NOT NULL DEFAULT '[]',
					platform_tag TEXT NOT NULL DEFAULT '',
					icon_path TEXT NOT NULL DEFAULT ''
				)
				"""
			)


	def table_names(self) -> set[str]:
		with self.connect() as conn:
			rows = conn.execute(
				"SELECT name FROM sqlite_master WHERE type='table'"
			).fetchall()
		return {str(row["name"]) for row in rows}
