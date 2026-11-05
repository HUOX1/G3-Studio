"""Grab the G3 Godot window to a PNG (Windows, GDI BitBlt on the window DC).

Usage:
    python .workbuddy/tools/capture_window.py out.png
    python .workbuddy/tools/capture_window.py out.png --series 0,120,240 --interval-ms 0

Only used for WB-05 visual verification; never shipped with the app.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.wintypes as wt
import sys
import time
from pathlib import Path

from PIL import Image

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

SRCCOPY = 0x00CC0020
PW_RENDERFULLCONTENT = 0x00000002


def enable_dpi_awareness() -> None:
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except Exception:
        user32.SetProcessDPIAware()


def find_window(title_part: str = "G3") -> int:
    handles: list[int] = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def _cb(hwnd, _lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length <= 0:
            return True
        buf = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buf, length + 1)
        title = buf.value
        if title_part.lower() in title.lower() and "G3" in title:
            handles.append(int(hwnd))
        return True

    user32.EnumWindows(_cb, 0)
    return handles[0] if handles else 0


def grab(hwnd: int, out: Path) -> tuple[int, int]:
    rect = wt.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    width = rect.right - rect.left
    height = rect.bottom - rect.top
    hdc_window = user32.GetWindowDC(hwnd)
    hdc_mem = gdi32.CreateCompatibleDC(hdc_window)
    bmp = gdi32.CreateCompatibleBitmap(hdc_window, width, height)
    gdi32.SelectObject(hdc_mem, bmp)
    ok = user32.PrintWindow(hwnd, hdc_mem, PW_RENDERFULLCONTENT)
    if not ok:
        gdi32.BitBlt(hdc_mem, 0, 0, width, height, hdc_window, 0, 0, SRCCOPY)

    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_ = [
            ("biSize", wt.DWORD),
            ("biWidth", wt.LONG),
            ("biHeight", wt.LONG),
            ("biPlanes", wt.WORD),
            ("biBitCount", wt.WORD),
            ("biCompression", wt.DWORD),
            ("biSizeImage", wt.DWORD),
            ("biXPelsPerMeter", wt.LONG),
            ("biYPelsPerMeter", wt.LONG),
            ("biClrUsed", wt.DWORD),
            ("biClrImportant", wt.DWORD),
        ]

    bmi = BITMAPINFOHEADER()
    bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bmi.biWidth = width
    bmi.biHeight = -height
    bmi.biPlanes = 1
    bmi.biBitCount = 32
    bmi.biCompression = 0
    buffer = ctypes.create_string_buffer(width * height * 4)
    gdi32.GetDIBits(hdc_mem, bmp, 0, height, buffer, ctypes.byref(bmi), 0)
    img = Image.frombuffer("RGBA", (width, height), buffer, "raw", "BGRA", 0, 1)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(out)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(hdc_mem)
    user32.ReleaseDC(hwnd, hdc_window)
    return width, height


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("out", type=Path)
    parser.add_argument("--series", default="")
    parser.add_argument("--interval-ms", type=int, default=0)
    parser.add_argument("--title", default="G3")
    args = parser.parse_args()

    enable_dpi_awareness()
    hwnd = find_window(args.title)
    if hwnd == 0:
        print("window not found")
        return 2
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.15)

    if args.series:
        offsets = [int(x) for x in args.series.split(",") if x.strip()]
        start = time.perf_counter()
        for offset in offsets:
            target = start + offset / 1000.0
            while time.perf_counter() < target:
                time.sleep(0.001)
            path = args.out.with_name(f"{args.out.stem}_{offset:04d}ms{args.out.suffix}")
            size = grab(hwnd, path)
            print(f"{offset}ms -> {path} {size}")
            if args.interval_ms:
                time.sleep(args.interval_ms / 1000.0)
    else:
        size = grab(hwnd, args.out)
        print(f"saved {args.out} {size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
