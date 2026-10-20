from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import logging
import re

from PIL import Image, ImageFilter

from g3_core.repository import LibraryRepository


logger = logging.getLogger("g3.cover_tool")


_SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def _strip_year_suffix(name: str) -> str:
	"""去掉文件名末尾的年份括号。"""
	cleaned = re.sub(r"\s*[\(\[]?\d{4}[\)\]]?\s*$", "", name).strip()
	return cleaned if cleaned else name


@dataclass(slots=True)
class CoverToolItem:
	"""扫描结果里的单个封面条目（每部电影一条）。"""
	matched_item_id: str = ""      # 电影 id
	matched_title: str = ""        # 电影标题
	filename: str = ""             # 匹配到的源封面文件名（空 = 没找到）
	file_path: str = ""            # 源封面完整路径（空 = 没找到）
	width: int = 0
	height: int = 0
	status: str = "not_found"      # not_found / auto_ok / needs_review / skip / error
	front_start_px: int = 0
	front_width_px: int = 0
	reason: str = ""


class CoverToolService:
	"""完整 DVD 封面 → 纯 Front 的自动提取工具。

	从「库内电影」出发：遍历影片 → 找源目录里的同名封面 → 自动检测 Front。
	"""

	def __init__(self, repository: LibraryRepository) -> None:
		self.repository = repository

	# ---------- 对外主入口 ----------

	def scan(
		self,
		source_dir: Path,
		scope: str,
		output_dir: Path,
		overwrite: bool = False,
	) -> list[CoverToolItem]:
		result: list[CoverToolItem] = []
		if not source_dir.is_dir():
			logger.warning("source dir missing: %s", source_dir)
			return result

		# 建源封面索引：{stem_lower → path}
		cover_index = self._build_source_index(source_dir)

		# 遍历库内电影
		for movie in self.repository.list_movies(scope):
			item = self._process_movie(movie, cover_index, output_dir, overwrite)
			result.append(item)

		return result

	def apply_one(
		self,
		source_path: Path,
		title: str,
		front_start_px: int,
		output_dir: Path,
	) -> Path:
		"""裁切一张图，写入 covers/movies/<title>.<ext>。"""
		if not source_path.is_file():
			raise FileNotFoundError(source_path)

		with Image.open(source_path) as img:
			w, h = img.size
			if front_start_px <= 0:
				front_start_px = 0
			if front_start_px >= w - 4:
				raise ValueError("front 起点超出图像范围")
			cropped = img.crop((front_start_px, 0, w, h))

			ext = source_path.suffix.lstrip(".").lower()
			if ext == "jpeg":
				ext = "jpg"
			output_dir.mkdir(parents=True, exist_ok=True)
			stem = self._sanitize(title)
			target = output_dir / f"{stem}.{ext}"

			for other_ext in ("jpg", "jpeg", "png", "webp", "bmp"):
				if other_ext == ext:
					continue
				stale = output_dir / f"{stem}.{other_ext}"
				if stale.is_file():
					try:
						stale.unlink()
					except OSError:
						pass

			tmp = target.with_suffix(target.suffix + ".tmp")
			if ext in ("jpg", "jpeg"):
				cropped = cropped.convert("RGB")
				cropped.save(tmp, format="JPEG", quality=92, optimize=True)
			elif ext == "webp":
				cropped = cropped.convert("RGB")
				cropped.save(tmp, format="WEBP", quality=92)
			elif ext == "png":
				cropped.save(tmp, format="PNG", optimize=True)
			else:
				cropped.save(tmp)
			tmp.replace(target)
		return target

	# ---------- 内部：处理单部电影 ----------

	def _process_movie(
		self,
		movie: dict,
		cover_index: dict[str, Path],
		output_dir: Path,
		overwrite: bool,
	) -> CoverToolItem:
		item = CoverToolItem(
			matched_item_id=str(movie["id"]),
			matched_title=str(movie["title"]),
		)

		# 先找源封面（无论是否已有正式封面）
		source_path = self._find_source_for_movie(movie, cover_index)
		if source_path is None:
			item.status = "not_found"
			item.reason = "源目录里没有匹配的封面"
			return item

		item.filename = source_path.name
		item.file_path = str(source_path)

		# 检测
		try:
			with Image.open(source_path) as img:
				item.width, item.height = img.size
				det = self._detect_front(img)
		except Exception as exc:
			item.status = "error"
			item.reason = f"读取失败：{exc}"
			return item

		item.front_start_px = int(det.get("front_start_px", 0))
		item.front_width_px = int(det.get("front_width_px", 0))

		# 已有正式封面 → 状态 "has_cover"（可点调整重新裁剪）；否则按检测结果
		existing = self._existing_cover_path(output_dir, str(movie["title"]))
		has_existing = existing is not None and not overwrite

		if has_existing:
			item.status = "has_cover"
			item.reason = "已有正式封面（点「调整」可重新裁剪）"
		else:
			item.status = det["status"]
			item.reason = str(det.get("reason", ""))

		return item

	@staticmethod
	def _build_source_index(source_dir: Path) -> dict[str, Path]:
		"""扫源目录，建立 {文件名 stem 小写 → 路径} 索引（含去括号变体）。"""
		index: dict[str, Path] = {}
		for path in sorted(source_dir.iterdir()):
			if not path.is_file():
				continue
			if path.suffix.lower() not in _SUPPORTED_EXTS:
				continue
			key = path.stem.casefold()
			if key not in index:
				index[key] = path
			stripped = _strip_year_suffix(path.stem).casefold()
			if stripped != key and stripped not in index:
				index[stripped] = path
		return index

	def _find_source_for_movie(
		self,
		movie: dict,
		cover_index: dict[str, Path],
	) -> Path | None:
		"""对一部电影，按多种 key 尝试匹配源封面。

		优先级：标题 → 视频文件名 stem → 视频所在文件夹名。
		"""
		candidates: list[str] = []

		# 1. 标题
		title = str(movie.get("title", "")).strip()
		if title:
			candidates.append(title)
			candidates.append(_strip_year_suffix(title))

		# 2. 视频路径
		item_id = str(movie["id"])
		src = self.repository.get_movie_source_path(item_id)
		if src:
			p = Path(src)
			# 文件名 stem
			if p.stem:
				candidates.append(p.stem)
				candidates.append(_strip_year_suffix(p.stem))
			# 文件夹名
			parent_name = p.parent.name
			if parent_name:
				candidates.append(parent_name)
				candidates.append(_strip_year_suffix(parent_name))

		# 去重 + 归一化
		seen: set[str] = set()
		keys: list[str] = []
		for c in candidates:
			cleaned = str(c).strip()
			if not cleaned:
				continue
			low = cleaned.casefold()
			if low in seen:
				continue
			seen.add(low)
			keys.append(low)

		for key in keys:
			if key in cover_index:
				return cover_index[key]
		return None

	@staticmethod
	def _existing_cover_path(output_dir: Path, title: str) -> Path | None:
		if not output_dir.is_dir():
			return None
		invalid = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
		stem = invalid.sub("_", title).strip().rstrip(". ") or "Untitled"
		for ext in ("jpg", "jpeg", "png", "webp", "bmp"):
			candidate = output_dir / f"{stem}.{ext}"
			if candidate.is_file():
				return candidate
		return None

	@staticmethod
	def _sanitize(title: str) -> str:
		invalid = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
		cleaned = invalid.sub("_", title).strip().rstrip(". ")
		return cleaned or "Untitled"

	# ---------- 内部：检测算法 ----------

	@staticmethod
	def _column_edge_strength(img: Image.Image) -> list[int]:
		gray = img.convert("L")
		edges = gray.filter(ImageFilter.FIND_EDGES)
		w, h = edges.size
		target_h = 80
		if h > target_h:
			new_w = max(1, int(w * target_h / h))
			edges = edges.resize((new_w, target_h), Image.BILINEAR)
			w = new_w
			h = target_h
		pixels = list(edges.getdata())
		col_sums = [0] * w
		for y in range(h):
			row_offset = y * w
			for x in range(w):
				col_sums[x] += pixels[row_offset + x]
		return col_sums

	@staticmethod
	def _smooth(arr: list[int], radius: int = 4) -> list[int]:
		n = len(arr)
		if n == 0:
			return arr
		out = [0] * n
		for i in range(n):
			lo = max(0, i - radius)
			hi = min(n, i + radius + 1)
			out[i] = sum(arr[lo:hi]) // (hi - lo)
		return out

	def _detect_front(self, img: Image.Image) -> dict:
		w, h = img.size

		if w < h * 1.15:
			return {
				"status": "auto_ok",
				"front_start_px": 0,
				"front_width_px": w,
				"reason": f"已经是竖版 Front，直接复制（{w}×{h}）",
			}

		col_sums = self._smooth(self._column_edge_strength(img), radius=4)
		n = len(col_sums)
		if n < 20:
			return {"status": "error", "reason": "图像过小"}

		min_spine = int(n * 0.04)
		max_spine = int(n * 0.18)

		center_lo = int(n * 0.25)
		center_hi = int(n * 0.75)
		best_left_peak = -1
		best_left_val = -1
		for x in range(center_lo, center_hi):
			if col_sums[x] > best_left_val:
				best_left_val = col_sums[x]
				best_left_peak = x

		if best_left_peak < 0:
			return {"status": "needs_review", "reason": "未找到结构边界"}

		search_lo = best_left_peak + min_spine
		search_hi = min(n - 1, best_left_peak + max_spine)
		best_right_peak = -1
		best_right_val = -1
		for x in range(search_lo, search_hi):
			if col_sums[x] > best_right_val:
				best_right_val = col_sums[x]
				best_right_peak = x

		if best_right_peak < 0:
			return {"status": "needs_review", "reason": "未找到 spine 右边界"}

		if best_right_val < best_left_val * 0.15:
			return {
				"status": "needs_review",
				"reason": "spine 右边界置信度低",
				"front_start_px": int(best_right_peak / n * w),
			}

		back_w = best_left_peak
		front_w = n - best_right_peak
		if back_w <= 0 or front_w <= 0:
			return {"status": "needs_review", "reason": "边界异常"}
		ratio = min(back_w, front_w) / max(back_w, front_w)
		if ratio < 0.55:
			return {
				"status": "needs_review",
				"reason": f"back/front 不对称（{ratio:.2f}）",
				"front_start_px": int(best_right_peak / n * w),
			}

		front_actual_w = (n - best_right_peak) / n * w
		aspect = front_actual_w / h
		if aspect < 0.55 or aspect > 0.95:
			return {
				"status": "needs_review",
				"reason": f"front 比例异常（{aspect:.2f}）",
				"front_start_px": int(best_right_peak / n * w),
			}

		front_start_px = int(best_right_peak / n * w)
		front_width_px = w - front_start_px
		return {
			"status": "auto_ok",
			"front_start_px": front_start_px,
			"front_width_px": front_width_px,
			"reason": f"已识别 Spine / Front 分界（Front {front_width_px}×{h}）",
		}