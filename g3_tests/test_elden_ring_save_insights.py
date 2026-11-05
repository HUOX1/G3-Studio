"""Save insights: read-only discovery and failure isolation."""
from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

from g3_core.services.elden_ring_save import read_local_save


def test_missing_appdata_never_guesses_save_location(monkeypatch):
    monkeypatch.delenv("APPDATA", raising=False)
    result = read_local_save()
    assert result["status"] == "not_found"


def test_missing_sl2_returns_not_found(monkeypatch, tmp_path):
    monkeypatch.setenv("APPDATA", str(tmp_path))
    (tmp_path / "EldenRing" / "76561198000000000").mkdir(parents=True)
    assert read_local_save()["status"] == "not_found"


def test_valid_sl2_uses_read_only_inspector(monkeypatch, tmp_path):
    monkeypatch.setenv("APPDATA", str(tmp_path))
    folder = tmp_path / "EldenRing" / "76561198000000000"
    folder.mkdir(parents=True)
    save = folder / "ER0000.sl2"
    save.write_bytes(b"test fixture")
    before = save.read_bytes()
    with patch("g3_core.services.elden_ring_save.inspect", return_value={
        "container_validation": {"checksum_ok": True}, "slots": []
    }) as inspector:
        result = read_local_save()
    assert result["status"] == "ready"
    inspector.assert_called_once_with(save)
    assert save.read_bytes() == before


def test_invalid_checksum_never_displays_unverified_details(monkeypatch, tmp_path):
    monkeypatch.setenv("APPDATA", str(tmp_path))
    folder = tmp_path / "EldenRing" / "12345"
    folder.mkdir(parents=True)
    (folder / "ER0000.sl2").write_bytes(b"test fixture")
    with patch("g3_core.services.elden_ring_save.inspect", return_value={
        "container_validation": {"checksum_ok": False}, "slots": [{"active": True}]
    }):
        result = read_local_save()
    assert result["status"] == "error"
    assert "data" not in result


def test_unparseable_sl2_is_a_status_not_an_exception(monkeypatch, tmp_path):
    monkeypatch.setenv("APPDATA", str(tmp_path))
    folder = tmp_path / "EldenRing" / "12345"
    folder.mkdir(parents=True)
    (folder / "ER0000.sl2").write_bytes(b"not a save")
    result = read_local_save()
    assert result["status"] == "error"
    assert "data" not in result
