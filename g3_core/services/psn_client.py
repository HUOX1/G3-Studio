from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
	from psnawp_api import PSNAWP
except ImportError:
	PSNAWP = None

logger = logging.getLogger("g3.psn")

class PSNError(RuntimeError):
	pass

@dataclass(slots=True)
class PSNConfig:
	npsso: str

	@classmethod
	def load(cls, path: Path) -> "PSNConfig":
		if not path.is_file():
			raise PSNError(f"PSN 配置文件不存在：{path}")
		try:
			data = json.loads(path.read_text(encoding="utf-8"))
		except Exception as exc:
			raise PSNError(f"读取 psn.json 失败：{exc}") from exc
		npsso = str(data.get("npsso", "")).strip()
		if not npsso:
			raise PSNError("psn.json 缺少 npsso")
		return cls(npsso=npsso)

class PSNClient:
	def __init__(self, config: PSNConfig) -> None:
		if PSNAWP is None:
			raise PSNError("未安装 psnawp 库，请先在终端运行 pip install psnawp")
		self.config = config
		try:
			self.api = PSNAWP(config.npsso)
			self.me = self.api.me()
		except Exception as exc:
			raise PSNError(f"PSN 认证失败，npsso 可能已过期: {exc}") from exc

	def get_library(self) -> list[dict[str, Any]]:
		try:
			titles = self.me.title_stats()
		except Exception as exc:
			raise PSNError(f"获取 PSN 游戏库失败: {exc}") from exc

		results = []
				# 允许的分类：加上 UNKNOWN（因为很多真正的游戏被索尼标成了这个）
		valid_categories = {
			"PS4", "PS5", "PS3", "PSVITA", "PSP", "UNKNOWN",
			"PS4_GAME", "PS5_GAME", "PS3_GAME", "PSVITA_GAME", "PSP_GAME"
		}

		# 名称关键词过滤黑名单（假游戏、试玩、主题、头像等）
		import re
		blacklist_keywords = re.compile(r'\b(Demo|Trial|Theme|Avatar|Beta|Test)\b', re.IGNORECASE)
		# 游戏 ID 黑名单（可选，保留你之前找出的特例）
		blacklist_ids = {
			"CUSA11470_00", "CUSA11469_00", "CUSA14642_00",
		}

		results = []
		for t in titles:
			platform = str(t.category).replace("PlatformCategory.", "")
			
			# 过滤 1：分类必须对上（UNKNOWN 也算）
			if platform.upper() not in valid_categories:
				continue
				
			# 过滤 2：直接踢掉黑名单里的假货
			tid = str(t.title_id).upper()
			if tid in blacklist_ids:
				continue
			
			# 过滤 3：名称包含 Demo/Trial 等关键词
			if blacklist_keywords.search(str(t.name)):
				continue
				
			playtime_sec = int(t.play_duration.total_seconds()) if t.play_duration else 0
			
			# 过滤 4：时长为 0 且没有奖杯（通常是非游戏内容，视你的需求保留）
			# (如果你确认某些游戏真的时长为0但确实是游戏，这行可以注释掉)
			# if playtime_sec == 0 and not t.has_trophy:
			# 	continue

			results.append({
				"title": t.name,
				"platform": platform,
				"playtime_seconds": playtime_sec,
				"external_id": tid,
			})
		return results