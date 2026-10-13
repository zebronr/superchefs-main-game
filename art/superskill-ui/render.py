"""Renders the superskill HUD mockups (mockup.html) to PNGs with headless Chrome or Edge.

Run from the repo root: python art/superskill-ui/render.py
Writes states.png, desktop.png, mobile.png and motion.png next to this script.
"""

import os
import pathlib
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
BROWSERS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
]
# view -> (output file, width, height, device scale)
VIEWS = {
    "states": ("states.png", 1340, 1330, 1),
    "desktop": ("desktop.png", 1280, 720, 1),
    "mobile": ("mobile.png", 944, 490, 2),
    "anim": ("motion.png", 1700, 880, 1),
}


def main():
    browser = next(b for b in BROWSERS if os.path.exists(b))
    url = (HERE / "mockup.html").as_uri()
    for view, (name, w, h, scale) in VIEWS.items():
        out = HERE / name
        subprocess.run(
            [
                browser,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--allow-file-access-from-files",
                f"--force-device-scale-factor={scale}",
                f"--window-size={w},{h}",
                "--virtual-time-budget=3000",
                f"--screenshot={out}",
                f"{url}#{view}",
            ],
            check=True,
            capture_output=True,
        )
        print("wrote", out)


if __name__ == "__main__":
    main()
