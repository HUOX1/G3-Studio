PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS library_items (
	id TEXT PRIMARY KEY,
	media_type TEXT NOT NULL,
	title TEXT NOT NULL,
	sort_title TEXT NOT NULL,
	description TEXT NOT NULL DEFAULT '',
	source_path TEXT NOT NULL DEFAULT '',
	offline INTEGER NOT NULL DEFAULT 0,
	library_scope TEXT NOT NULL DEFAULT 'main',
	watched_seconds INTEGER NOT NULL DEFAULT 0,
	total_seconds INTEGER NOT NULL DEFAULT 0,
	watched_complete INTEGER NOT NULL DEFAULT 0,
	created_at TEXT NOT NULL,
	updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS game_metadata (
	item_id TEXT PRIMARY KEY REFERENCES library_items(id) ON DELETE CASCADE,
	developer TEXT NOT NULL DEFAULT '',
	publisher TEXT NOT NULL DEFAULT '',
	release_year INTEGER,
	genres TEXT NOT NULL DEFAULT '',
	runtime_minutes INTEGER NOT NULL DEFAULT 0,
	tags TEXT NOT NULL DEFAULT '',
	notes TEXT NOT NULL DEFAULT '',
	vote_average REAL NOT NULL DEFAULT 0.0,
	tagline TEXT NOT NULL DEFAULT '',
	tmdb_id INTEGER NOT NULL DEFAULT 0,
	release_date TEXT NOT NULL DEFAULT '',
	screenshots_json TEXT NOT NULL DEFAULT '',
	metacritic INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS movie_episodes (
	id TEXT PRIMARY KEY,
	item_id TEXT NOT NULL REFERENCES library_items(id) ON DELETE CASCADE,
	season INTEGER,
	episode INTEGER,
	display_order INTEGER NOT NULL DEFAULT 0,
	video_path TEXT NOT NULL,
	title TEXT NOT NULL DEFAULT '',
	overview TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS games (
	item_id TEXT PRIMARY KEY REFERENCES library_items(id) ON DELETE CASCADE,
	platform TEXT NOT NULL DEFAULT '',
	profile_type TEXT NOT NULL DEFAULT 'direct',
	launch_exe TEXT NOT NULL DEFAULT '',
	launch_args TEXT NOT NULL DEFAULT '',
	working_directory TEXT NOT NULL DEFAULT '',
	content_path TEXT NOT NULL DEFAULT '',
	monitor_exe TEXT NOT NULL DEFAULT '',
	wait_timeout_s INTEGER NOT NULL DEFAULT 300,
	run_as_admin INTEGER NOT NULL DEFAULT 0,
	playtime_seconds INTEGER NOT NULL DEFAULT 0,
	playtime_edit_count INTEGER NOT NULL DEFAULT 0,
	last_played_at TEXT,
	sgdb_id INTEGER NOT NULL DEFAULT 0,
	steam_appid INTEGER NOT NULL DEFAULT 0,
	english_name TEXT NOT NULL DEFAULT '',
	psn_playtime_seconds INTEGER NOT NULL DEFAULT 0,	
	source TEXT NOT NULL DEFAULT 'manual',
	playtime_source TEXT NOT NULL DEFAULT 'g3',
	external_id TEXT NOT NULL DEFAULT '',
	namespace_id TEXT NOT NULL DEFAULT '',
	artifact_id TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_movie_episodes_item
ON movie_episodes(item_id, display_order);

CREATE TABLE IF NOT EXISTS terminal_state (
	key TEXT PRIMARY KEY,
	value_json TEXT NOT NULL
);

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
);