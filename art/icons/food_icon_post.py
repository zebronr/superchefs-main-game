"""Post pass for food_icon.py: the sticker border, and a sheet comparing every style on the real UI colours.

Run from the repo root after the Blender pass: python art/icons/food_icon_post.py <Name>
Makes <Name>_shadow.png (the chosen style: padded, centred, hard drop shadow) from <Name>_flat.png, plus the
comparison styles (outline, sticker, toon) and art/icons/out/<Name>_sheet.png when every style exists.
"""

import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageStat

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
NAME = sys.argv[1]
STYLES = ["flat", "shadow", "outline", "sticker", "soft", "toon"]
LABELS = {"flat": "FLAT (current)", "shadow": "FLAT + SHADOW", "outline": "OUTLINE", "sticker": "STICKER", "soft": "SOFT 3D", "toon": "TOON"}
CARD, CARD_SHADOW = (98, 144, 176), (62, 102, 133)  # the in-game blue card and its shadow
BORDER = 14  # sticker border, px at 512


INK = (52, 22, 16)  # warm near-black outline
SHADOW_COLOUR, SHADOW_ALPHA, SHADOW_OFFSET = (40, 20, 15), 0.60, 20  # hard drop shadow, offset in px at 512
FILL = 0.72  # food + shadow fit in this central share of the 512 px canvas (14 % padding each side)
TONE = {"Cheese": (242, 200, 95)}  # per icon: shift the mean colour to this (the raw cheese texture reads too yellow)


def border(src, dst, width, colour, shadow_alpha):
    """Grows the icon's silhouette by width px in colour behind it (plus an optional soft drop shadow)."""
    icon = Image.open(src).convert("RGBA")
    pad = width * 3
    big = Image.new("RGBA", (icon.width + pad * 2, icon.height + pad * 2), (0, 0, 0, 0))
    big.paste(icon, (pad, pad))
    alpha = big.getchannel("A").point(lambda a: 255 if a > 40 else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(width * 2 + 1)).filter(ImageFilter.GaussianBlur(1.2))
    out = Image.new("RGBA", big.size, (0, 0, 0, 0))
    if shadow_alpha:
        shadow = grown.filter(ImageFilter.GaussianBlur(6)).point(lambda a: a * shadow_alpha)
        out.paste((40, 20, 15, 255), (0, 6), shadow)
    out.paste((*colour, 255), (0, 0), grown)
    out = Image.alpha_composite(out, big)
    out.resize(icon.size, Image.LANCZOS).save(dst)  # shrink so the border fits inside the icon


def tone(icon, target):
    """Per-channel gain so the icon's mean opaque colour lands on target (e.g. a less yellow cheese).

    Pixels much darker than the median (tinted recesses, see CAVITY in food_icon.py) are left out of the mean, so
    darkening the holes doesn't brighten the rest of the icon.
    """
    opaque = icon.getchannel("A").point(lambda a: 255 if a > 200 else 0)
    lum = icon.convert("L")
    median = ImageStat.Stat(lum, opaque).median[0]
    body = ImageChops.multiply(opaque, lum.point(lambda v: 255 if v >= median * 0.8 else 0))
    mean = ImageStat.Stat(icon.convert("RGB"), body).mean
    r, g, b, a = icon.split()
    r, g, b = (ch.point(lambda v, k=t / m: min(255, round(v * k))) for ch, t, m in zip((r, g, b), target, mean))
    return Image.merge("RGBA", (r, g, b, a))


# How far (0-1) to move from box-centring toward weight-centring, horizontally.
MASS_CENTRE = 0.5


def hard_shadow(src, dst, offset, colour, alpha):
    """Flat icon with a sharp drop shadow straight down (the UI's cards cast theirs the same way).

    The food is cropped to its alpha bounding box and scaled so food + shadow fit in the central FILL of the canvas,
    then centred on that combined box, so every icon gets the same padding whatever the model's shape.
    """
    icon = Image.open(src).convert("RGBA")
    if NAME in TONE:
        icon = tone(icon, TONE[NAME])
    food = icon.crop(icon.getchannel("A").getbbox())
    side = round(icon.width * FILL)
    scale = min(side / food.width, (side - offset) / food.height)
    food = food.resize((round(food.width * scale), round(food.height * scale)), Image.LANCZOS)
    x, y = (icon.width - food.width) // 2, (icon.height - food.height - offset) // 2
    # A lopsided shape (the cheese wedge, heavy on its tall side) looks off-centre when centred by its box, so shift
    # it MASS_CENTRE of the way toward centring its visual weight (alpha centroid), staying inside the canvas.
    coverage = food.getchannel("A")
    columns = [sum(coverage.crop((cx, 0, cx + 1, food.height)).getdata()) for cx in range(food.width)]
    total = sum(columns)
    if total > 0:
        centroid = sum(cx * w for cx, w in enumerate(columns)) / total
        shift = round((food.width / 2 - centroid) * MASS_CENTRE)
        x = max(0, min(icon.width - food.width, x + shift))
    placed = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    placed.paste(food, (x, y))
    mask = placed.getchannel("A").point(lambda a: int(a * alpha))
    out = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    out.paste((*colour, 255), (0, offset), mask)
    Image.alpha_composite(out, placed).save(dst)


def font(size):
    for f in ("C:/Windows/Fonts/arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def sheet():
    cell, gap = 300, 24
    w = gap + len(STYLES) * (cell + gap)
    h = 2 * (cell + gap) + gap + 40
    img = Image.new("RGBA", (w, h), (238, 230, 214, 255))
    d = ImageDraw.Draw(img)
    for i, style in enumerate(STYLES):
        icon = Image.open(os.path.join(OUT, f"{NAME}_{style}.png")).convert("RGBA")
        x = gap + i * (cell + gap)
        d.text((x + 6, 10), LABELS[style], fill=(60, 40, 30), font=font(22))
        # row 1: on the blue order card (shadow frame under it, like the game's cards)
        y = 44
        d.rounded_rectangle((x, y + 8, x + cell, y + cell + 8), 18, fill=CARD_SHADOW)
        d.rounded_rectangle((x, y, x + cell, y + cell), 18, fill=CARD)
        img.alpha_composite(icon.resize((cell - 30, cell - 30), Image.LANCZOS), (x + 15, y + 15))
        # row 2: small, the size it shows at on an order ticket, on dark and light
        y = 44 + cell + gap
        d.rounded_rectangle((x, y, x + cell // 2 - 6, y + cell // 2 - 6), 12, fill=(30, 32, 40))
        d.rounded_rectangle((x + cell // 2 + 6, y, x + cell, y + cell // 2 - 6), 12, fill=(255, 255, 255))
        small = icon.resize((64, 64), Image.LANCZOS)
        img.alpha_composite(small, (x + (cell // 2 - 6 - 64) // 2, y + (cell // 2 - 6 - 64) // 2))
        img.alpha_composite(small, (x + cell // 2 + 6 + (cell // 2 - 6 - 64) // 2, y + (cell // 2 - 6 - 64) // 2))
        d.text((x + 6, y + cell // 2 + 4), "64 px", fill=(110, 90, 70), font=font(18))
    img.save(os.path.join(OUT, f"{NAME}_sheet.png"))


def path(style):
    return os.path.join(OUT, f"{NAME}_{style}.png")


# the chosen style is "shadow"; the rest only exist for the style comparison, made when their source was rendered
hard_shadow(path("flat"), path("shadow"), SHADOW_OFFSET, SHADOW_COLOUR, SHADOW_ALPHA)
border(path("flat"), path("outline"), 9, INK, 0)
border(path("flat"), path("sticker"), BORDER, (255, 255, 255), 0.35)
if os.path.exists(path("toonbase")):
    border(path("toonbase"), path("toon"), 9, INK, 0)
if all(os.path.exists(path(s)) for s in STYLES):
    sheet()
print("done")
