"""Read-only Elden Ring PC .sl2 inspector for G3 save insight pages.

Reads character/profile records, known character state fields, inventory occupancy,
region-list count, and death count. Does not edit saves, deserialize code or request
network access. Unknown numeric IDs are not translated into invented game labels.

Based on publicly documented PC BND4/UserDataX structural layouts.
"""
from __future__ import annotations
import hashlib
import json
import struct
from pathlib import Path

HEADER_SIZE = 0x300
SLOT_SIZE = 0x280000
BLOCK_SIZE = SLOT_SIZE + 0x10
UD10_DATA_OFFSET = 0x19003B0
UD10_SIZE = 0x60000
UD11_DATA_OFFSET = 0x19603C0
UD11_SIZE = 0x240010  # includes 16 trailing padding bytes; matches checksum in this file
FLAG_OFFSET = 0x1954
PROFILE_OFFSET = 0x195E
PROFILE_SIZE = 0x24C
CLASS_NAMES = [
    'Vagabond', 'Warrior', 'Hero', 'Bandit', 'Astrologer', 'Prophet',
    'Confessor', 'Samurai', 'Prisoner', 'Wretch'
]
STAT_NAMES = ('vigor', 'mind', 'endurance', 'strength', 'dexterity',
              'intelligence', 'faith', 'arcane')


def u32(data: bytes, pos: int) -> int:
    if pos < 0 or pos + 4 > len(data):
        raise ValueError(f'Out-of-bounds u32 at 0x{pos:x}')
    return struct.unpack_from('<I', data, pos)[0]


def parse_inventory(data: bytes, base: int, common_capacity: int,
                    key_capacity: int) -> tuple[dict, int]:
    size = 16 + 12 * (common_capacity + key_capacity)
    if base < 0 or base + size > len(data):
        raise ValueError('Inventory extends beyond slot')
    common_header_count = u32(data, base)
    common_base = base + 4
    key_header_offset = common_base + 12 * common_capacity
    key_header_count = u32(data, key_header_offset)
    key_base = key_header_offset + 4

    def occupied(start: int, capacity: int) -> int:
        return sum(1 for j in range(capacity)
                   if u32(data, start + 12 * j) not in (0, 0xFFFFFFFF))

    common_actual = occupied(common_base, common_capacity)
    key_actual = occupied(key_base, key_capacity)
    if (common_header_count != common_actual or
            key_header_count != key_actual):
        raise ValueError('Inventory header counts differ from occupied entries')
    return {
        'ordinary_entries': common_actual,
        'key_entries': key_actual,
        'total_entries': common_actual + key_actual,
        'note': 'These count occupied inventory records, not total quantities or unique collectible types.'
    }, base + size


def parse_nonempty_slot(slot: bytes, profile: dict) -> dict:
    version = u32(slot, 0)
    if version == 0:
        raise ValueError('Cannot parse empty slot')
    pos = 0x20
    gaitem_records = 5120 if version > 81 else 5118
    for _ in range(gaitem_records):
        handle = u32(slot, pos)
        pos += 8  # handle + item ID
        category = handle & 0xF0000000
        if handle != 0 and category != 0xC0000000:
            pos += 8
            if category == 0x80000000:
                pos += 5
    player = pos
    if player + 0x1B0 > SLOT_SIZE:
        raise ValueError('Invalid character offset')

    stats = {name: u32(slot, player + 0x34 + i*4)
             for i, name in enumerate(STAT_NAMES)}
    lvl = u32(slot, player + 0x60)
    name = slot[player + 0x94:player + 0xB4].decode('utf-16le', errors='replace').split('\0')[0]
    if any(not (1 <= v <= 99) for v in stats.values()):
        raise ValueError('Invalid stat range')
    if lvl != sum(stats.values()) - 79 or lvl != profile['level'] or name != profile['character_name']:
        raise ValueError('Slot character and global profile do not agree')
    class_id = slot[player + 0xB7]
    slot_info = {
        'save_format_version': version,
        'character_name': name,
        'character_level': lvl,
        'character_class_id': class_id,
        'character_class': CLASS_NAMES[class_id] if class_id < len(CLASS_NAMES) else None,
        'seconds_played': profile['seconds_played'],
        'hours_played': round(profile['seconds_played'] / 3600, 2),
        'attributes': stats,
        'runes_held': u32(slot, player + 0x64),
        'runes_memory_raw': u32(slot, player + 0x68),
        'vitals': {
            'hp': {'current': u32(slot, player + 0x08), 'max': u32(slot, player + 0x0C)},
            'fp': {'current': u32(slot, player + 0x14), 'max': u32(slot, player + 0x18)},
            'stamina': {'current': u32(slot, player + 0x24), 'max': u32(slot, player + 0x28)},
        },
        'map_id_raw': slot[4:8].hex(),
    }
    # Offset chain: version-aware GaItems -> PlayerGameData -> equipment
    # -> inventory -> projectile list -> storage -> visited regions -> misc data.
    pos = player + 0x1B0 + 13*16 + 88 + 28 + 88 + 88
    held, pos = parse_inventory(slot, pos, 2688, 384)
    slot_info['inventory_held'] = held
    pos += 116 + 140 + 24
    projectile_count = u32(slot, pos)
    if projectile_count > 256:
        raise ValueError('Invalid projectile count')
    pos += 4 + projectile_count*8
    pos += 156 + 12 + 303
    storage, pos = parse_inventory(slot, pos, 1920, 128)
    slot_info['inventory_storage'] = storage
    pos += 256
    regions_count = u32(slot, pos)
    if regions_count > 1024:
        raise ValueError('Invalid region count')
    pos += 4
    slot_info['region_list_entries'] = regions_count
    pos += 4*regions_count
    pos += 40 + 1 + 68 + 4 + 4 + 4
    menu_size = u32(slot, pos)
    if not (0 <= menu_size <= 0x10000):
        raise ValueError('Invalid menu block size')
    pos += 4 + menu_size
    pos += 52 + 0x1B588
    pos += 4  # two unknown u16 tutorial header fields
    tutorial_size = u32(slot, pos)
    if not (0 <= tutorial_size <= 0x10000):
        raise ValueError('Invalid tutorial block size')
    pos += 4 + tutorial_size + 3
    slot_info['total_deaths_recorded'] = u32(slot, pos)
    pos += 4
    character_type = struct.unpack_from('<i', slot, pos)[0]
    pos += 4
    if character_type not in (-1, 0, 1):
        raise ValueError('Unexpected character type, likely misaligned')
    online_flag = slot[pos]
    pos += 1 + 4
    slot_info['last_rested_grace_id_raw'] = u32(slot, pos)
    pos += 4 + 1 + 4 + 4
    if online_flag not in (0,1):
        raise ValueError('Unexpected session flag, likely misaligned')
    if pos + 0x1BF99F > SLOT_SIZE:
        raise ValueError('Event flag range extends beyond slot')
    slot_info['event_flags'] = {
        'data_section_present': True,
        'decoded_meaningful_flags': False,
        'note': 'Quest/boss/ending conclusions require a tested game-specific event-flag ID map.'
    }
    slot_info['validation'] = {
        'level_formula_matches': True,
        'global_profile_matches': True,
        'inventory_counts_match': True,
        'dynamic_sections_in_bounds': True
    }
    return slot_info


def inspect(path: Path) -> dict:
    data = path.read_bytes()
    if not data.startswith(b'BND4') or len(data) != UD11_DATA_OFFSET + UD11_SIZE:
        raise ValueError('Unsupported .sl2 container size or magic')
    checksums = []
    for i in range(10):
        off = HEADER_SIZE + i*BLOCK_SIZE
        chunk = data[off+16:off+16+SLOT_SIZE]
        checksums.append(hashlib.md5(chunk).digest() == data[off:off+16])
    for off, size in ((UD10_DATA_OFFSET, UD10_SIZE), (UD11_DATA_OFFSET, UD11_SIZE)):
        checksums.append(hashlib.md5(data[off:off+size]).digest() == data[off-16:off])
    profiles = []
    for i in range(10):
        off = UD10_DATA_OFFSET + PROFILE_OFFSET + i*PROFILE_SIZE
        level, seconds, runes_mem = struct.unpack_from('<III', data, off+0x22)
        name = data[off:off+32].decode('utf-16le', errors='replace').split('\0')[0]
        active = bool(data[UD10_DATA_OFFSET + FLAG_OFFSET + i])
        slot_off = HEADER_SIZE + i * BLOCK_SIZE + 16
        slot = data[slot_off:slot_off+SLOT_SIZE]
        version = u32(slot, 0)
        profile = {'slot': i+1, 'active': active, 'data_present': version != 0,
                   'character_name': name, 'level': level, 'seconds_played': seconds}
        if version:
            profile['details'] = parse_nonempty_slot(slot, profile)
        else:
            profile = {'slot': i+1, 'active': active, 'data_present': False}
        profiles.append(profile)
    return {
        'schema': 'g3.elden_ring.save_insights.v0.2',
        'source': {'game': 'Elden Ring', 'format': 'PC SL2 BND4',
                   'size_bytes': len(data), 'mode': 'read-only'},
        'container_validation': {'checksum_ok': all(checksums),
                                 'slot_md5_ok': all(checksums[:10]),
                                 'global_data_md5_ok': checksums[10],
                                 'regulation_md5_ok': checksums[11]},
        'slots': profiles,
        'used_slots': sum(s['data_present'] for s in profiles),
        'active_slots': sum(s['active'] for s in profiles),
        'limitations': [
            'Inactive slots with residual data are NOT current selectable game profiles.',
            'Inventory entries are record counts, not item quantities or collection completion rates.',
            'Region entries are internal region-list entries, not a map exploration percentage.',
            'Event flag meanings, equipment names, boss list, and quests are not decoded.',
            'Steam account identifiers are intentionally not exported.',
            'Original save file is never modified.'
        ]
    }




def read_local_save() -> dict:
    """Find PC Steam SL2 in the local Windows roaming profile. Never write it."""
    import os
    appdata = os.environ.get("APPDATA", "")
    if not appdata:
        return {"status": "not_found", "message": "未找到 Windows APPDATA 存档目录"}
    save_root = Path(appdata) / "EldenRing"
    if not save_root.is_dir():
        return {"status": "not_found", "message": "未找到艾尔登法环本地存档"}
    candidates = []
    try:
        for folder in save_root.iterdir():
            if not folder.is_dir() or not folder.name.isdigit():
                continue
            entry = folder / "ER0000.sl2"
            if entry.is_file():
                candidates.append((entry.stat().st_mtime, entry))
    except OSError as exc:
        return {"status": "error", "message": f"读取存档目录失败：{exc}"}
    if not candidates:
        return {"status": "not_found", "message": "未找到 ER0000.sl2（不使用备份或云端文件）"}
    # Deterministic latest-save selection; no account folder name is returned.
    candidates.sort(key=lambda pair: (pair[0], str(pair[1])), reverse=True)
    try:
        result = inspect(candidates[0][1])
        if not result["container_validation"]["checksum_ok"]:
            return {"status": "error", "message": "存档校验未通过，已停止解析"}
        return {"status": "ready", "data": result}
    except (ValueError, OSError, struct.error, UnicodeError) as exc:
        return {"status": "error", "message": f"当前存档版本暂不能可靠解析：{exc}"}
