from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(slots=True)
class MediaAsset:
    id: str
    owner_id: str
    kind: str
    path: Path
    cache_path: Path | None
    priority: int
    source: str