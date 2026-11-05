from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_launcher_has_external_splash_and_native_window_gate():
    runtime = (ROOT / "g3_launcher" / "runtime.py").read_text(encoding="utf-8")
    splash = (ROOT / "g3_launcher" / "startup_splash.py").read_text(encoding="utf-8")
    assert "create_startup_splash()" in runtime
    assert "NativeWindowGate(process.pid)" in runtime
    assert "window_gate.hide()" not in runtime
    assert "window_gate.reveal()" in runtime
    assert "G3_STARTUP_READY_FILE" in runtime
    assert "overrideredirect(True)" in splash
    assert "EnumWindows" in splash


def test_frontend_signals_only_when_launcher_requests_it():
    main = (ROOT / "g3_frontend" / "scripts" / "main.gd").read_text(encoding="utf-8")
    assert "func _g3_signal_external_startup_ready()" in main
    assert 'OS.get_environment("G3_STARTUP_READY_FILE")' in main
    assert "ready_file.store_string(\"ready\")" in main
