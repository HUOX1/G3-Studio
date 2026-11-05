from __future__ import annotations

import ctypes
import logging
import os
from ctypes import wintypes

logger = logging.getLogger("g3.launcher")


class StartupSplash:
    """Small dependency-free splash UI; Tk is optional and failure is non-fatal."""

    def __init__(self) -> None:
        import tkinter as tk
        from tkinter import ttk

        self._tk = tk
        self._root = tk.Tk()
        self._closed = False
        self._phase = 0
        self._status = tk.StringVar(value="正在启动 G3")
        self._root.title("G3 Startup")
        self._root.overrideredirect(True)
        self._root.attributes("-topmost", True)
        self._root.configure(bg="#08111f")
        self._root.geometry(f"{self._root.winfo_screenwidth()}x{self._root.winfo_screenheight()}+0+0")

        canvas = tk.Canvas(self._root, bg="#08111f", highlightthickness=0, bd=0)
        canvas.pack(fill="both", expand=True)
        canvas.create_oval(0, 0, 520, 520, fill="#0b1d31", outline="")
        canvas.create_oval(
            self._root.winfo_screenwidth() - 420,
            self._root.winfo_screenheight() - 420,
            self._root.winfo_screenwidth() + 100,
            self._root.winfo_screenheight() + 100,
            fill="#101b31",
            outline="",
        )
        canvas.create_text(
            self._root.winfo_screenwidth() // 2,
            self._root.winfo_screenheight() // 2 - 70,
            text="G3",
            fill="#e8f2ff",
            font=("Segoe UI", 62, "bold"),
        )
        canvas.create_text(
            self._root.winfo_screenwidth() // 2,
            self._root.winfo_screenheight() // 2 - 10,
            text="GAME  ·  GRID  ·  GALLERY",
            fill="#7dabc9",
            font=("Segoe UI", 11),
        )
        self._status_label = tk.Label(
            self._root,
            textvariable=self._status,
            bg="#08111f",
            fg="#c5d5e7",
            font=("Segoe UI", 11),
        )
        self._status_label.place(relx=0.5, rely=0.5, y=58, anchor="n")
        self._bar = ttk.Progressbar(self._root, mode="indeterminate", length=280)
        self._bar.place(relx=0.5, rely=0.5, y=94, anchor="n")
        self._bar.start(14)
        self._root.update_idletasks()
        self._root.update()

    def set_status(self, text: str) -> None:
        if self._closed:
            return
        self._status.set(text)
        self.pump()

    def pump(self) -> None:
        if self._closed:
            return
        try:
            self._root.update_idletasks()
            self._root.update()
        except self._tk.TclError:
            self._closed = True

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        try:
            self._bar.stop()
            self._root.destroy()
        except self._tk.TclError:
            pass


def create_startup_splash() -> StartupSplash | None:
    if os.name != "nt" or os.environ.get("G3_DISABLE_STARTUP_SPLASH") == "1":
        return None
    try:
        return StartupSplash()
    except Exception:
        logger.warning("External startup splash is unavailable; continuing without it.", exc_info=True)
        return None


class NativeWindowGate:
    """Bring top-level windows owned by the launched Godot process forward."""

    SW_HIDE = 0
    SW_SHOW = 5
    GW_OWNER = 4

    def __init__(self, process_id: int) -> None:
        if os.name != "nt":
            raise OSError("NativeWindowGate is only supported on Windows")
        self.process_id = int(process_id)
        self._user32 = ctypes.WinDLL("user32", use_last_error=True)
        self._enum_windows = self._user32.EnumWindows
        self._enum_windows.argtypes = [wintypes.WNDENUMPROC, wintypes.LPARAM]
        self._enum_windows.restype = wintypes.BOOL
        self._get_pid = self._user32.GetWindowThreadProcessId
        self._get_pid.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
        self._get_pid.restype = wintypes.DWORD
        self._get_window = self._user32.GetWindow
        self._get_window.argtypes = [wintypes.HWND, wintypes.UINT]
        self._get_window.restype = wintypes.HWND
        self._show_window = self._user32.ShowWindow
        self._show_window.argtypes = [wintypes.HWND, ctypes.c_int]
        self._show_window.restype = wintypes.BOOL
        self._set_foreground = self._user32.SetForegroundWindow
        self._set_foreground.argtypes = [wintypes.HWND]
        self._set_foreground.restype = wintypes.BOOL
        self._update_window = self._user32.UpdateWindow
        self._update_window.argtypes = [wintypes.HWND]
        self._update_window.restype = wintypes.BOOL

    def _windows(self) -> list[int]:
        found: list[int] = []
        callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

        def visit(hwnd: int, _lparam: int) -> bool:
            pid = wintypes.DWORD()
            self._get_pid(hwnd, ctypes.byref(pid))
            if pid.value == self.process_id and not self._get_window(hwnd, self.GW_OWNER):
                found.append(int(hwnd))
            return True

        callback = callback_type(visit)
        self._enum_windows(callback, 0)
        return found

    def hide(self) -> None:
        """Hide every unowned top-level window belonging to the Godot process."""
        for hwnd in self._windows():
            self._show_window(hwnd, self.SW_HIDE)

    def reveal(self) -> None:
        windows = self._windows()
        for hwnd in windows:
            self._show_window(hwnd, self.SW_SHOW)
            self._update_window(hwnd)
        if windows:
            self._set_foreground(windows[0])
