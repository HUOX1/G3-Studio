from __future__ import annotations

import json
import logging
import re
import uuid
from dataclasses import dataclass, field
from pathlib import Path


logger = logging.getLogger("g3.fontsets")


# ── 每个 scope 支持的字段 ──
FIELD_KEYS_MOVIES = [
	"movie_title",
	"movie_year",
	"movie_meta",
	"movie_desc",
	"movie_tagline",
	"ui_default",
]

FIELD_KEYS_GAMES = [
	"game_title",
	"game_meta",
	"game_playtime",
	"game_desc",
	"game_sidebar",
	"ui_default",
]

FIELD_KEYS_BY_SCOPE: dict[str, list[str]] = {
	"movies": FIELD_KEYS_MOVIES,
	"games": FIELD_KEYS_GAMES,
}

# 兼容旧代码里对 FIELD_KEYS 的直接引用（默认取电影）
FIELD_KEYS = FIELD_KEYS_MOVIES


_DEFAULT_SIZES: dict[str, int] = {
	# movies
	"movie_title": 34,
	"movie_year": 14,
	"movie_meta": 14,
	"movie_desc": 16,
	"movie_tagline": 22,
	# games
	"game_title": 40,
	"game_meta": 13,
	"game_playtime": 14,
	"game_desc": 15,
	"game_sidebar": 14,
	# shared
	"ui_default": 15,
}


FONTSET_SCOPES = {"movies", "games"}

# 字体组别 ID 只允许安全文件名字符（"default" 与 uuid4 天然满足）。
# 首字符必须是字母/数字，因此 "."、".."、".hidden"、"-x" 等全部被拒；
# 不含 / \ : 及通配符等字符，路径遍历与绝对路径无法构造。
_FONTSET_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,99}")

# Windows 保留设备名（大小写不敏感），按 ID 首个点之前的部分判断。
_WINDOWS_RESERVED_NAMES = frozenset(
	{"CON", "PRN", "AUX", "NUL"}
	| {f"COM{i}" for i in range(1, 10)}
	| {f"LPT{i}" for i in range(1, 10)}
)


def is_valid_fontset_id(fontset_id: str) -> bool:
	"""校验字体组别 ID 能否安全映射为 fontsets 目录内的文件名。

	拒绝路径分隔符、路径遍历、绝对路径/盘符、Windows 非法文件名字符
	（< > : " | ? * 与控制字符）、保留设备名及超长/空 ID。
	"""
	clean = str(fontset_id).strip()
	if not _FONTSET_ID_RE.fullmatch(clean):
		return False
	if clean.split(".", 1)[0].upper() in _WINDOWS_RESERVED_NAMES:
		return False
	return True


@dataclass
class Fontset:
	id: str
	name: str
	scope: str = "movies"
	fields: dict[str, dict] = field(default_factory=dict)

	def to_dict(self) -> dict:
		return {
			"id": self.id,
			"name": self.name,
			"scope": self.scope,
			"fields": self.fields,
		}


def _make_default_fields(scope: str) -> dict[str, dict]:
	keys = FIELD_KEYS_BY_SCOPE.get(scope, FIELD_KEYS_MOVIES)
	fields: dict[str, dict] = {}
	for key in keys:
		fields[key] = {"font_path": "", "font_size": _DEFAULT_SIZES[key]}
	return fields


def make_default_fontset(scope: str = "movies") -> Fontset:
	# 默认组别永远用 "default" 一个 id；按 scope 给不同字段表
	return Fontset(
		id="default",
		name="默认",
		scope=scope,
		fields=_make_default_fields(scope),
	)


class FontsetStore:
	def __init__(self, root: Path) -> None:
		self.root = Path(root)
		self.root.mkdir(parents=True, exist_ok=True)

	def _fontset_file(self, fontset_id: str) -> Path | None:
		"""把组别 ID 安全解析为 fontsets 目录内的文件路径。

		ID 非法、解析后越出根目录、目标本身是符号链接或指向外部的
		硬链接时返回 None，调用方按"不存在/非法输入"的既有语义处理；
		绝不返回根目录之外的路径。
		"""
		clean_id = str(fontset_id).strip()
		if clean_id == "default" or not is_valid_fontset_id(clean_id):
			return None
		path = self.root / f"{clean_id}.json"
		try:
			resolved = path.resolve()
			root_resolved = self.root.resolve()
		except OSError:
			return None
		if path.is_symlink() or resolved.parent != root_resolved:
			logger.warning("fontset path is a symlink or escaped root: %r", fontset_id)
			return None
		try:
			if path.exists() and path.stat().st_nlink > 1:
				# NTFS 硬链接：读写会波及字体目录之外的同一物理文件，按越界拒绝。
				logger.warning("fontset file is a hard link: %r", fontset_id)
				return None
		except OSError:
			return None
		return path

	def list_fontsets(self) -> list[Fontset]:
		"""列出所有组别（含电影和游戏两个 scope）。"""
		result: list[Fontset] = [
			make_default_fontset("movies"),
			make_default_fontset("games"),
		]
		# default 组别允许出现两次（不同 scope），所以用 (id, scope) 去重
		seen_keys = {("default", "movies"), ("default", "games")}
		for path in sorted(self.root.glob("*.json")):
			# 枚举项同样复用 _fontset_file 统一安全检查：ID 非法、符号链接、
			# 硬链接或越界的文件直接跳过，单个异常文件不影响整个列表。
			safe_path = self._fontset_file(path.stem)
			if safe_path is None:
				continue
			fontset = self._load_file(safe_path)
			if fontset is None:
				continue
			key = (fontset.id, fontset.scope)
			if key in seen_keys:
				continue
			seen_keys.add(key)
			result.append(fontset)
		return result

	def get(self, fontset_id: str, scope: str = "movies") -> Fontset:
		clean_id = str(fontset_id).strip()
		if clean_id == "default":
			return make_default_fontset(scope)
		path = self._fontset_file(clean_id)
		if path is None:
			logger.warning("fontset id rejected (illegal or escaping path): %r", fontset_id)
			return make_default_fontset(scope)
		if not path.is_file():
			return make_default_fontset(scope)
		fontset = self._load_file(path)
		if fontset is None:
			return make_default_fontset(scope)
		# 若组别 scope 与请求 scope 不符，回退默认
		if fontset.scope != scope:
			logger.warning(
				"fontset %s has scope %s, but %s requested; fallback to default",
				fontset_id, fontset.scope, scope,
			)
			return make_default_fontset(scope)
		return fontset

	def _load_file(self, path: Path) -> Fontset | None:
		try:
			payload = json.loads(path.read_text(encoding="utf-8"))
		except (OSError, json.JSONDecodeError) as exc:
			logger.warning("load fontset failed: %s (%s)", path, exc)
			return None
		if not isinstance(payload, dict):
			return None

		fontset_id = str(payload.get("id", path.stem)).strip() or path.stem
		name = str(payload.get("name", fontset_id)).strip() or fontset_id
		scope = str(payload.get("scope", "movies")).strip() or "movies"
		if scope not in FONTSET_SCOPES:
			scope = "movies"

		keys = FIELD_KEYS_BY_SCOPE.get(scope, FIELD_KEYS_MOVIES)
		raw_fields = payload.get("fields", {})
		fields: dict[str, dict] = {}
		for key in keys:
			entry = raw_fields.get(key) if isinstance(raw_fields, dict) else None
			if isinstance(entry, dict):
				font_path = str(entry.get("font_path", "")).strip()
				try:
					font_size = int(entry.get("font_size", _DEFAULT_SIZES[key]))
				except (ValueError, TypeError):
					font_size = _DEFAULT_SIZES[key]
				if font_size <= 0:
					font_size = _DEFAULT_SIZES[key]
			else:
				font_path = ""
				font_size = _DEFAULT_SIZES[key]
			fields[key] = {"font_path": font_path, "font_size": font_size}

		return Fontset(id=fontset_id, name=name, scope=scope, fields=fields)

	def save(
		self,
		fontset_id: str,
		name: str,
		fields: dict,
		scope: str = "movies",
	) -> Fontset:
		"""保存（创建或覆盖）一个字体组别。`default` 不可写。"""
		clean_id = str(fontset_id).strip() or "default"
		if clean_id == "default":
			raise ValueError("默认组别不可编辑")
		path = self._fontset_file(clean_id)
		if path is None:
			raise ValueError(f"非法的字体组别 ID：{clean_id!r}")
		clean_name = str(name).strip() or clean_id
		clean_scope = str(scope).strip() or "movies"
		if clean_scope not in FONTSET_SCOPES:
			clean_scope = "movies"

		keys = FIELD_KEYS_BY_SCOPE.get(clean_scope, FIELD_KEYS_MOVIES)
		safe_fields: dict[str, dict] = {}
		for key in keys:
			entry = fields.get(key) if isinstance(fields, dict) else None
			if isinstance(entry, dict):
				font_path = str(entry.get("font_path", "")).strip()
				try:
					font_size = int(entry.get("font_size", _DEFAULT_SIZES[key]))
				except (ValueError, TypeError):
					font_size = _DEFAULT_SIZES[key]
				if font_size <= 0:
					font_size = _DEFAULT_SIZES[key]
			else:
				font_path = ""
				font_size = _DEFAULT_SIZES[key]
			safe_fields[key] = {"font_path": font_path, "font_size": font_size}

		fontset = Fontset(
			id=clean_id, name=clean_name, scope=clean_scope, fields=safe_fields,
		)
		payload = {
			"id": clean_id,
			"name": clean_name,
			"scope": clean_scope,
			"fields": safe_fields,
		}
		temporary = path.with_suffix(".tmp")
		temporary.write_text(
			json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
			encoding="utf-8",
		)
		temporary.replace(path)
		return fontset

	def create(
		self,
		name: str,
		copy_from: str | None = None,
		scope: str = "movies",
	) -> Fontset:
		"""新建一个字体组别。copy_from 不为空则复制该组别的字段。"""
		clean_name = str(name).strip() or "新组别"
		clean_scope = str(scope).strip() or "movies"
		if clean_scope not in FONTSET_SCOPES:
			clean_scope = "movies"
		new_id = str(uuid.uuid4())
		if copy_from:
			source = self.get(copy_from, clean_scope)
			fields = {
				k: {
					"font_path": v.get("font_path", ""),
					"font_size": v.get("font_size", _DEFAULT_SIZES[k]),
				}
				for k, v in source.fields.items()
			}
		else:
			fields = _make_default_fields(clean_scope)
		return self.save(new_id, clean_name, fields, clean_scope)

	def rename(self, fontset_id: str, new_name: str, scope: str = "movies") -> Fontset:
		"""重命名一个字体组别。"""
		clean_id = str(fontset_id).strip()
		if clean_id == "default":
			raise ValueError("默认组别不可重命名")
		if not is_valid_fontset_id(clean_id):
			raise ValueError(f"非法的字体组别 ID：{clean_id!r}")
		existing = self.get(clean_id, scope)
		if existing.id != clean_id:
			raise ValueError(f"字体组别不存在：{clean_id}")
		return self.save(clean_id, new_name, existing.fields, existing.scope)

	def delete(self, fontset_id: str) -> bool:
		"""删除一个字体组别。`default` 不可删。"""
		clean_id = str(fontset_id).strip()
		if clean_id == "default":
			return False
		path = self._fontset_file(clean_id)
		if path is None:
			logger.warning("fontset id rejected (illegal or escaping path): %r", fontset_id)
			return False
		if not path.is_file():
			return False
		try:
			path.unlink()
		except OSError as exc:
			logger.warning("delete fontset failed: %s (%s)", path, exc)
			return False
		return True