"""诊断 Steam HTML 简介里的图片。一次性脚本，用完可删。"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from g3_core.services.steam_client import SteamClient  # noqa


def main(appid: int) -> None:
    client = SteamClient()
    raw = client._get_json(
        "https://store.steampowered.com/api/appdetails",
        {"appids": str(appid), "l": "schinese", "cc": "cn"},
    )
    entry = raw.get(str(appid), {})
    if not isinstance(entry, dict) or not entry.get("success"):
        print("Steam 返回失败:", entry)
        return
    data = entry.get("data", {})
    if not isinstance(data, dict):
        print("data 结构异常")
        return

    print("=== name:", data.get("name"))
    print()

    for field in ("about_the_game", "detailed_description"):
        html = str(data.get(field, "") or "")
        print(f"=== {field}  长度={len(html)}")
        if not html:
            continue
        img_urls = re.findall(r'<img[^>]+src="([^"]+)"', html)
        print(f"    <img> 数量: {len(img_urls)}")
        for i, u in enumerate(img_urls):
            tail = u.split("/")[-1].split("?")[0][:100]
            print(f"      [{i}] {tail}")
        video_tags = re.findall(r"<video[^>]*>", html)
        if video_tags:
            print(f"    <video> 数量: {len(video_tags)}")
        # 找所有 <source src="...">
        source_urls = re.findall(r'<source[^>]+src="([^"]+)"', html)
        for i, u in enumerate(source_urls):
            tail = u.split("/")[-1].split("?")[0][:100]
            print(f"      <source> [{i}] {tail}")
        print()


if __name__ == "__main__":
    appid = int(sys.argv[1]) if len(sys.argv) > 1 else 2138710
    main(appid)