from __future__ import annotations
import logging
import json
import re
from pathlib import Path
from g3_core.repository import LibraryRepository
from g3_core.services.psn_client import PSNClient, PSNConfig, PSNError

logger = logging.getLogger("g3.psn_library")

class PSNLibraryScanner:
    def __init__(self, repository: LibraryRepository) -> None:
        self.repository = repository

    def scan(self, config_path) -> dict:
        games = []
        override_path = config_path.parent / "psn_override.json"
        
        # 1. 优先读取本地洗好的 JSON
        if override_path.is_file():
            logger.info("使用本地覆盖文件: %s", override_path)
            try:
                data = json.loads(override_path.read_text(encoding="utf-8"))
                if isinstance(data, list):
                    games = data
            except Exception as e:
                logger.error("读取 psn_override.json 失败: %s", e)
        
        # 2. 如果没有覆盖文件，才去请求网络
        if not games:
            try:
                config = PSNConfig.load(config_path)
                client = PSNClient(config)
                games = client.get_library()
            except PSNError as exc:
                logger.error(str(exc))
                return {"items": [], "summary": {"total": 0, "new": 0, "existing": 0, "errors": 1}, "error": str(exc)}
        
        items = []
        for g in games:
            existing = self.repository.find_game_by_external_id(g["external_id"], "psn")
            
            # 清理名字里的 ™ 和 ®
            raw_title = str(g.get("title", ""))
            clean_title = re.sub(r'[™®©]', '', raw_title).strip()
            
            english_name = str(g.get("english_name", ""))
            if not english_name:
                english_name = clean_title if not bool(re.search(r'[\u4e00-\u9fa5]', clean_title)) else ""

            items.append({
                "title": clean_title,
                "english_name": english_name,
                "platform": g.get("platform", "PS4"),
                "psn_playtime_seconds": g.get("playtime_seconds", 0),
                "external_id": g["external_id"],
                "already_exists": existing is not None
            })
            
        items.sort(key=lambda x: str(x["title"]).lower())
            
        new_count = sum(1 for i in items if not i["already_exists"])
        return {
            "items": items,
            "summary": {
                "total": len(items),
                "new": new_count,
                "existing": len(items) - new_count,
                "errors": 0,
            }
        }