"""Regression cases for Epic and Ubisoft handoffs."""
from g3_core.services.game_process_probe import ProcessInfo, choose_game_pids


def proc(pid, parent, name, path):
    return ProcessInfo(pid, parent, name, path)


def test_epic_preexisting_launcher_new_game_under_manifest_directory():
    ps = {
        12: proc(12, 1, 'EpicGamesLauncher.exe', '/tools/Epic/EpicGamesLauncher.exe'),
        14: proc(14, 12, 'EpicWebHelper.exe', '/tools/Epic/EpicWebHelper.exe'),
        20: proc(20, 12, 'Sifu-Win64-Shipping.exe', '/games/Sifu/Binaries/Win64/Sifu-Win64-Shipping.exe'),
    }
    assert choose_game_pids(ps, {12, 14}, install_dir='/games/Sifu') == {20}


def test_uplay_new_game_when_launcher_was_already_open():
    ps = {
        22: proc(22, 1, 'UbisoftConnect.exe', '/client/UbisoftConnect.exe'),
        44: proc(44, 22, 'game.exe', '/games/AC/Game/game.exe'),
    }
    assert choose_game_pids(ps, {22}, install_dir='/games/AC') == {44}


def test_new_launcher_not_confused_with_game():
    ps = {
        23: proc(23, 1, 'UbisoftConnect.exe', '/games/AC/UbisoftConnect.exe'),
        24: proc(24, 23, 'game.exe', '/games/AC/Game/game.exe'),
    }
    assert choose_game_pids(ps, set(), install_dir='/games/AC', launch_pid=23) == {24}


def test_epic_bootstrapper_is_not_counted_as_game():
    ps = {3: proc(3, 1, 'EOSBootstrapper.exe', '/games/Foo/EOSBootstrapper.exe')}
    assert choose_game_pids(ps, set(), install_dir='/games/Foo', launch_pid=3) == set()
