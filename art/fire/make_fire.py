"""Bakes looping fire flipbooks for the combo fire on the coin card.

Each sheet is 1024x1024: 8 x 8 frames of 128x128, read left to right, top to bottom (Config.UI.Combo.FireSheet).
The flame is a soft teardrop eaten away at the top by noise that scrolls upward; the noise is periodic (FFT), so
the last frame flows back into the first. Writes FireOrange.png and FireBlue.png next to this script.

    python art/fire/make_fire.py
"""
import os

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

FRAMES = 64
COLUMNS = 8
SIZE = 128
SS = 2  # supersampling
HERE = os.path.dirname(os.path.abspath(__file__))

RAMPS = {
    # heat -> (r, g, b, a), from cool edge to hot core
    "FireOrange": [
        (0.00, (140, 15, 5, 0)),
        (0.10, (190, 35, 10, 120)),
        (0.25, (230, 70, 15, 220)),
        (0.45, (255, 125, 25, 255)),
        (0.70, (255, 175, 45, 255)),
        (0.90, (255, 220, 100, 255)),
        (1.00, (255, 245, 190, 255)),
    ],
    "FireBlue": [
        (0.00, (10, 25, 150, 0)),
        (0.10, (20, 55, 210, 120)),
        (0.25, (40, 95, 250, 220)),
        (0.45, (60, 150, 255, 255)),
        (0.70, (95, 195, 255, 255)),
        (0.90, (165, 230, 255, 255)),
        (1.00, (230, 250, 255, 255)),
    ],
}
GLOW = {"FireOrange": (255, 120, 30), "FireBlue": (60, 140, 255)}


def periodic_noise(height, width, beta, seed, stretch=1.0):
    """Fractal noise that tiles in both directions (filtered white noise in frequency space). stretch > 1 makes
    the features taller than they are wide, like flame tongues."""
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(height)[:, None]
    fx = np.fft.fftfreq(width)[None, :]
    f = np.sqrt(fx * fx + (fy * stretch) * (fy * stretch))
    f[0, 0] = 1
    spectrum = (rng.normal(size=(height, width)) + 1j * rng.normal(size=(height, width))) / f ** beta
    spectrum[0, 0] = 0
    field = np.real(np.fft.ifft2(spectrum))
    field -= field.min()
    return field / field.max()


def ramp(heat, stops):
    out = np.zeros(heat.shape + (4,))
    positions = [s[0] for s in stops]
    for channel in range(4):
        values = [s[1][channel] for s in stops]
        out[..., channel] = np.interp(heat, positions, values)
    return out


def main():
    n = SIZE * SS
    tex_h = n * 2
    big = periodic_noise(tex_h, n, 1.75, 1, stretch=3.0)  # licking tongues
    fine = periodic_noise(tex_h, n, 1.6, 2, stretch=2.0)  # flicker detail
    wave = periodic_noise(tex_h, n, 2.6, 3)  # sideways sway

    ys, xs = np.mgrid[0:n, 0:n]
    v = 1 - (ys + 0.5) / n  # 0 at the bottom, 1 at the top
    u = (xs + 0.5 - n / 2) / (n / 2)  # -1 .. 1

    heats = []
    for frame in range(FRAMES):
        def sample(field, cycles):
            shift = int(round(frame / FRAMES * tex_h * cycles)) % tex_h
            # Upward scroll: each pixel reads the field further down every frame.
            return np.roll(field, -shift, axis=0)[:n, :]

        b = sample(big, 1)
        f = sample(fine, 2)
        w = sample(wave, 1)
        # Sway grows with height, so the base stays planted.
        su = u + 0.5 * v ** 1.3 * (w - 0.5) * 2
        # A teardrop: round at the base, tapering to a point, hottest low down.
        width = 0.1 + 0.5 * (1 - v) ** 0.9
        column = np.exp(-((su / width) ** 2) * 1.6)
        rise = (1 - v) ** 1.5
        base = np.clip((v - 0.04) / 0.14, 0, 1) ** 0.6  # fades in above the frame's bottom edge
        # Upward-scrolling noise splits the column into separate pointed tongues, more so higher up.
        noise = (0.8 * b + 0.2 * f - 0.5) * 2
        heat = column * base * (1.25 * rise + 0.55) + noise * column ** 0.5 * (0.15 + 0.55 * v) - 0.4 * v
        heat = np.clip(heat * 1.2, 0, 1) ** 1.2
        heats.append(heat)

    for name, stops in RAMPS.items():
        sheet = Image.new("RGBA", (SIZE * COLUMNS, SIZE * (FRAMES // COLUMNS)), (0, 0, 0, 0))
        glow_color = np.array(GLOW[name], dtype=float)
        for frame, heat in enumerate(heats):
            rgba = ramp(heat, stops)
            # Soft glow around the flame, under it.
            glow_a = gaussian_filter(rgba[..., 3] / 255, sigma=6 * SS) * 0.55
            a = rgba[..., 3] / 255
            out_a = a + glow_a * (1 - a)
            rgb = (rgba[..., :3] * a[..., None] + glow_color * (glow_a * (1 - a))[..., None]) / np.maximum(out_a, 1e-4)[..., None]
            img = np.dstack([rgb, out_a * 255]).clip(0, 255).astype(np.uint8)
            tile = Image.fromarray(img, "RGBA").resize((SIZE, SIZE), Image.LANCZOS)
            sheet.paste(tile, ((frame % COLUMNS) * SIZE, (frame // COLUMNS) * SIZE))
        sheet.save(os.path.join(HERE, name + ".png"))
    print("done")


if __name__ == "__main__":
    main()
