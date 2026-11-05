"""Pure matching rules for launcher handoff and unrelated existing processes."""
from g3_core.services.game_process_probe import ProcessInfo, choose_game_pids, is_beneath


def proc(pid, parent, name, path):
    return ProcessInfo(pid=pid, parent_pid=parent, name=name, path=path)


def test_new_process_under_install_directory():
    before = {10, 11}
    ps = {
        10: proc(10, 1, "EpicGamesLauncher.exe", "/apps/Epic/EpicGamesLauncher.exe"),
        11: proc(11, 1, "game.exe", "/games/Other/game.exe"),
        12: proc(12, 10, "game.exe", "/games/Test/Binaries/game.exe"),
        13: proc(13, 1, "Updater.exe", "/apps/Other/Updater.exe"),
    }
    assert choose_game_pids(ps, before, install_dir="/games/Test") == {12}


def test_short_lived_launcher_handoff_by_directory():
    # Startup launcher (pid=21) has exited by the time the snapshot was taken.
    ps = {22: proc(22, 21, "Game-Win64-Shipping.exe", "/games/Sifu/Binaries/Game-Win64-Shipping.exe")}
    assert choose_game_pids(ps, {1}, install_dir="/games/Sifu", launch_pid=21) == {22}


def test_existing_game_process_is_not_attached():
    ps = {42: proc(42, 3, "game.exe", "/games/Test/game.exe")}
    assert choose_game_pids(ps, {42}, install_dir="/games/Test") == set()


def test_user_monitor_exe_is_explicit_and_new_only():
    ps = {
        10: proc(10, 3, "Target.exe", "/old/Target.exe"),
        11: proc(11, 3, "Target.exe", "/new/Target.exe"),
        12: proc(12, 3, "Other.exe", "/new/Other.exe"),
    }
    assert choose_game_pids(ps, {10}, monitor_exe="Target.exe") == {11}


def test_no_substring_directory_false_positive():
    assert not is_beneath("/games/Test2/game.exe", "/games/Test")
    assert is_beneath("/games/Test/Binaries/game.exe", "/games/Test")
