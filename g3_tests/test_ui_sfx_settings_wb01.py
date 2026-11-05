from pathlib import Path

import pytest

from g3_core.settings import TerminalSettings


def test_ui_sfx_defaults_are_backward_compatible():
    settings = TerminalSettings.from_dict({"ui_sfx": True, "ui_sfx_volume": 0.6})
    assert settings.ui_sfx_overrides == {}


def test_ui_sfx_mapping_round_trip(tmp_path: Path):
    settings = TerminalSettings.default()
    settings.ui_sfx_overrides = {"boot": "user://g3_ui_sfx/boot_123.wav"}
    settings.save(tmp_path / "settings.json")
    loaded = TerminalSettings.load(tmp_path / "settings.json")
    assert loaded.ui_sfx_overrides == settings.ui_sfx_overrides


@pytest.mark.parametrize("invalid", [
    {"unknown": "user://g3_ui_sfx/s.wav"},
    {"boot": "C:/private/audio.wav"},
    {"boot": 42},
    ["user://g3_ui_sfx/audio.wav"],
])
def test_ui_sfx_rejects_invalid_mappings(invalid):
    settings = TerminalSettings.default().to_dict()
    settings["ui_sfx_overrides"] = invalid
    with pytest.raises(ValueError):
        TerminalSettings.from_dict(settings)
