"""Google App Campaign images (landscape 1200x628, square 1200x1200, portrait
1200x1500) from full-size simulator stills, in the ad videos' style.

  python3 tool/make_ad_images.py <stills dir>

The stills dir holds solve.png, perfect.png, raceA.png, raceB.png, won.png
(1206x2622 frames grabbed from the ad recordings with ffmpeg).
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_TITLE = os.path.join(ROOT, 'assets/fonts/LuckiestGuy-Regular.ttf')
FONT_BODY = os.path.join(ROOT, 'assets/fonts/Fredoka-SemiBold.ttf')
ICON = os.path.join(ROOT, 'store/google_play/icon_512.png')
OUT = os.path.join(ROOT, 'store/ads/images')
stills = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
YELLOW = (255, 214, 64)


def still(name):
    return Image.open(os.path.join(stills, name)).convert('RGBA')


def background(w, h, top=(38, 198, 186), bottom=(20, 96, 140)):
    im = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    im = im.convert('RGBA')
    tiles = Image.new('RGBA', (w, h))
    td = ImageDraw.Draw(tiles)
    r = random.Random(w * 7 + h)
    f = ImageFont.truetype(FONT_TITLE, 60)
    for _ in range(w * h // 90000):
        x, y, s = r.randrange(-40, w), r.randrange(-40, h), r.randrange(80, 130)
        td.rounded_rectangle((x, y, x + s, y + s), radius=s // 5, fill=(255, 255, 255, 22), outline=(255, 255, 255, 30), width=3)
        td.text((x + s / 2, y + s / 2 + 4), str(r.randrange(1, 10)), font=f, anchor='mm', fill=(255, 255, 255, 30))
    return Image.alpha_composite(im, tiles)


def phone(im, shot, x, y, h, crop_top=0.0, crop_bottom=1.0):
    """Paste a rounded, white-rimmed phone screenshot (optionally cropped)."""
    sw, sh = shot.size
    shot = shot.crop((0, int(sh * crop_top), sw, int(sh * crop_bottom)))
    w = round(shot.width * h / shot.height)
    shot = shot.resize((w, h), Image.LANCZOS)
    rad = max(24, w // 10)
    b = max(6, w // 60)
    shadow = Image.new('RGBA', im.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x - b, y - b + 14, x + w + b, y + h + b + 14), radius=rad + b, fill=(0, 30, 50, 110))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    ImageDraw.Draw(im).rounded_rectangle((x - b, y - b, x + w + b, y + h + b), radius=rad + b, fill='white')
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=rad, fill=255)
    im.paste(shot, (x, y), mask)
    return w


def title(im, lines, x, y, size, color='white', anchor='mm'):
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_TITLE, size)
    for i, line in enumerate(lines):
        d.text((x, y + i * size * 1.08), line, font=f, fill=color, anchor=anchor, stroke_width=max(4, size // 12), stroke_fill=(40, 30, 90))


def body(im, text, x, y, size, anchor='mm'):
    ImageDraw.Draw(im).text((x, y), text, font=ImageFont.truetype(FONT_BODY, size), anchor=anchor, fill='white', stroke_width=3, stroke_fill=(20, 60, 90))


def button(im, text, cx, cy, w, h):
    d = ImageDraw.Draw(im)
    x0, y0 = cx - w / 2, cy - h / 2
    d.rounded_rectangle((x0, y0 + h * .09, x0 + w, y0 + h * 1.09), radius=h / 2, fill=(196, 84, 22))
    d.rounded_rectangle((x0, y0, x0 + w, y0 + h), radius=h / 2, fill=(255, 128, 48))
    d.rounded_rectangle((x0 + h * .3, y0 + h * .1, x0 + w - h * .3, y0 + h * .3), radius=h * .1, fill=(255, 170, 110))
    title(im, [text], cx, cy + h * .04, int(h * .52))


def icon(im, x, y, s):
    ic = Image.open(ICON).convert('RGBA').resize((s, s), Image.LANCZOS)
    mask = Image.new('L', (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s - 1, s - 1), radius=s // 4.5, fill=255)
    im.paste(ic, (x, y), mask)


def save(im, name):
    im.convert('RGB').save(os.path.join(OUT, name), quality=92)
    print(name, im.size)


solve, perfect, race_a, race_b, won = (still(n) for n in ('solve.png', 'perfect.png', 'raceA.png', 'raceB.png', 'won.png'))

def w_of(h, top, bottom):
    return round(1206 * h / (2622 * (bottom - top)))


# Landscape 1200x628: race (two phones) + text.
im = background(1200, 628)
pw = w_of(500, 0.0, 0.62)
phone(im, race_a, 1200 - 2 * pw - 70, 64, 500, 0.0, 0.62)
phone(im, race_b, 1200 - pw - 30, 64, 500, 0.0, 0.62)
icon(im, 40, 40, 90)
title(im, ['RACE A', 'FRIEND LIVE!'], 200, 250, 54)
body(im, 'Who finishes first?', 200, 375, 26)
button(im, 'PLAY FREE', 200, 480, 260, 68)
save(im, 'landscape_race_1200x628.jpg')

# Landscape 1200x628: relaxing solve + 3 stars.
im = background(1200, 628)
phone(im, solve, 1200 - 2 * pw - 70, 64, 500, 0.0, 0.62)
phone(im, perfect, 1200 - pw - 30, 64, 500, 0.0, 0.62)
icon(im, 40, 40, 90)
title(im, ['RELAX WITH', 'SUDOKU'], 200, 250, 58)
body(im, 'Easy to Expert, free', 200, 375, 26)
button(im, 'PLAY FREE', 200, 480, 260, 68)
save(im, 'landscape_solve_1200x628.jpg')

# Square 1200x1200: two phones under a title.
sw = w_of(740, 0.0, 0.62)
for name, a, b, cap, color, sub in (
        ('square_race_1200x1200.jpg', race_a, race_b, 'RACE A FRIEND LIVE!', 'white', 'Send a 6-digit code. See their progress live.'),
        ('square_solve_1200x1200.jpg', solve, perfect, '3 STARS. PERFECT!', YELLOW, 'Relaxing Sudoku, from Easy to Expert')):
    im = background(1200, 1200)
    title(im, [cap], 600, 110, 84, color=color)
    gap = (1200 - 2 * sw) // 3
    phone(im, a, gap, 210, 740, 0.0, 0.62)
    phone(im, b, 2 * gap + sw, 210, 740, 0.0, 0.62)
    body(im, sub, 600, 1060, 40)
    save(im, name)

# Portrait 1200x1500 (4:5): one phone each.
pw = w_of(900, 0.0, 0.66)
for name, shot, cap in (('portrait_won_1200x1500.jpg', won, ['RACE A FRIEND', 'LIVE!']),
                        ('portrait_solve_1200x1500.jpg', solve, ['RELAX WITH', 'SUDOKU'])):
    im = background(1200, 1500)
    title(im, cap, 600, 115, 96)
    phone(im, shot, (1200 - pw) // 2, 330, 900, 0.0, 0.66)
    button(im, 'PLAY FREE', 600, 1375, 420, 92)
    save(im, name)
