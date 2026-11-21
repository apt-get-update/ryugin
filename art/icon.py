# Ryūgin's icon, in the Deepin 2022 style of the music icons: a frosted jade sleeve with a CD
# peeking out behind it, a white Chinese dragon chasing a ♪ (as dragons chase the pearl).
# The dragon: "Chinese black dragon.svg", Wikimedia Commons, CC BY-SA 3.0 (chinese-dragon.svg).
# Run from this folder (needs rsvg-convert): python3 icon.py ->
#   icon.png (1024 px), icon-sailfish.png (the sleeve alone, filling a Sailfish OS launcher
#   shape) and icon-tray.png (龍 in white, for the tray; needs Noto Sans CJK).
import io
import subprocess

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

S, A = 1024, 3  # size, supersampling
JADE = (38, 160, 132)


def supersampled(draw):
    m = Image.new("L", (S * A, S * A))
    draw(ImageDraw.Draw(m))
    return m.resize((S, S), Image.LANCZOS)


def white(alpha):
    return Image.merge("RGBA", [Image.new("L", (S, S), 255)] * 3 + [alpha])


def clip(im, mask):
    im = im.copy()
    im.putalpha(ImageChops.multiply(im.getchannel("A"), mask))
    return im


def dragon(width):
    """The dragon in white; its drawn lines cut out; the far half a light grey (Deepin)."""
    png = subprocess.run(["rsvg-convert", "-w", str(width), "chinese-dragon.svg"], capture_output=True, check=True).stdout
    a = np.asarray(Image.open(io.BytesIO(png)).convert("RGBA"), float) / 255
    ink = np.clip(((1 - a[..., :3].mean(2)) * a[..., 3] - 0.35) / 0.4, 0, 1)
    h, w = ink.shape
    yy, xx = np.mgrid[:h, :w]
    tone = np.where(xx / w + yy / h > 1.05, 232, 255).astype(float)
    return Image.fromarray(np.dstack([tone, tone, tone + 2, ink * 255]).clip(0, 255).astype("uint8"), "RGBA")


def note(d, x, y, s):
    """A ♪ like SPlayer's: a round head, a straight stem, a straight flag rising right."""
    d.ellipse([(x - 58 * s) * A, (y - 46 * s) * A, (x + 58 * s) * A, (y + 46 * s) * A], fill=255)
    sx = x + 40 * s
    d.rounded_rectangle([(sx - 15 * s) * A, (y - 250 * s) * A, (sx + 15 * s) * A, (y - 10 * s) * A], 15 * s * A, fill=255)
    bar = [(sx - 15 * s, y - 250 * s), (sx + 120 * s, y - 292 * s), (sx + 120 * s, y - 218 * s), (sx - 15 * s, y - 178 * s)]
    d.polygon([(px * A, py * A) for px, py in bar], fill=255)
    d.ellipse([(sx + 84 * s) * A, (y - 292 * s) * A, (sx + 156 * s) * A, (y - 218 * s) * A], fill=255)


def curve(p, n=100):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(tuple(A * (u**3 * p[0][k] + 3 * u * u * t * p[1][k] + 3 * u * t * t * p[2][k] + t**3 * p[3][k]) for k in (0, 1)))
    return out


def glow(color):
    """The colour with a soft light in its middle."""
    yy, xx = np.mgrid[:S, :S]
    k = np.clip(1 - np.hypot(xx - S / 2, yy - S / 2) / (S / 2), 0, 1) ** 1.6 * 0.35
    rgb = np.array(color, float) + (255 - np.array(color, float)) * k[..., None]
    return Image.fromarray(np.dstack([rgb, np.full((S, S), 255.0)]).astype("uint8"), "RGBA")


def mark():
    """The dragon and its note, white."""
    lay = Image.new("RGBA", (S, S))
    lay.alpha_composite(dragon(550), (150, 290))
    lay.alpha_composite(white(supersampled(lambda d: note(d, 680, 430, 0.4))))
    return lay


# The CD behind, peeking out to the right
cd = Image.new("RGBA", (S, S))
d = ImageDraw.Draw(cd)
cx, cy, r = 650, 512, 340
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(238, 238, 242, 255))
d.ellipse((cx - 120, cy - 120, cx + 120, cy + 120), fill=(222, 222, 228, 255))
d.ellipse((cx - 34, cy - 34, cx + 34, cy + 34), fill=(0, 0, 0, 0))

# The sleeve: frosted glass, the CD blurred behind it, jade over that, two flowing lines
sleeve = supersampled(lambda d: d.rounded_rectangle([v * A for v in (70, 150, 800, 880)], 56 * A, fill=255))
frost = Image.new("RGBA", (S, S), JADE + (255,))
frost.alpha_composite(cd.filter(ImageFilter.GaussianBlur(34)))
tint = glow(JADE)
tint.putalpha(int(255 * 0.82))
frost.alpha_composite(tint)
lines = supersampled(lambda d: [d.line(curve(p), fill=80, width=7 * A, joint="curve") for p in (
    [(40, 700), (300, 560), (560, 900), (990, 620)], [(40, 780), (320, 640), (600, 980), (990, 700)])])
frost.alpha_composite(white(lines))
frost.alpha_composite(mark())

icon = Image.new("RGBA", (S, S))
icon.alpha_composite(cd)
icon.alpha_composite(clip(frost, sleeve))
icon.save("icon.png")

# Sailfish OS: no padding, the art fills a base shape of its launcher (Jolla's "Apps icon
# story"): here the media player's, round but for a near-square top-right corner.
shape = supersampled(lambda d: (d.rounded_rectangle([0, 0, S * A - 1, S * A - 1], S * A // 2, fill=255),
                                d.rounded_rectangle([S * A // 2, 0, S * A - 1, S * A // 2], S * A * 3 // 86, fill=255)))
sailfish = clip(frost, sleeve).crop((70, 150, 800, 880)).resize((S, S), Image.LANCZOS)
clip(sailfish, shape).save("icon-sailfish.png")

# Tray: 龍 (ryū, dragon, the first kanji of 龍吟) in white, as the other tray icons: the
# dragon's fine lines were a smudge at 22 px.
tray = Image.new("RGBA", (S, S))
d = ImageDraw.Draw(tray)
font = ImageFont.truetype("/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc", int(S * 0.92))
b = d.textbbox((0, 0), "龍", font=font)
d.text(((S - b[2] - b[0]) / 2, (S - b[3] - b[1]) / 2), "龍", font=font, fill=(255, 255, 255, 255))
tray.save("icon-tray.png")
