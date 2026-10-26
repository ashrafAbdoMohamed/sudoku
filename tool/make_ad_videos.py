"""Builds the portrait (1080x1920) Google App Campaign videos from simulator
recordings made with the demo flags from tool/ad_recording.patch
(git apply it, run with --dart-define=NO_ADS=true --dart-define=DEMO_MS=380,
record with `xcrun simctl io <sim> recordVideo`, then git apply -R it).

  python3 tool/make_ad_videos.py <solo.mp4> <raceA.mp4> <raceB.mp4> <work dir>

Clip times below are for the recordings of 2026-10-24; re-check them with a
contact sheet when re-recording. Needs ffmpeg (no drawtext needed: all text is
drawn here with PIL) and Pillow.
"""
import math
import os
import random
import struct
import subprocess
import sys
import wave

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_TITLE = os.path.join(ROOT, 'assets/fonts/LuckiestGuy-Regular.ttf')
FONT_BODY = os.path.join(ROOT, 'assets/fonts/Fredoka-SemiBold.ttf')
ICON = os.path.join(ROOT, 'store/google_play/icon_512.png')
SFX = os.path.join(ROOT, 'assets/sfx')
OUT = os.path.join(ROOT, 'store/ads')
W, H, FPS, SR = 1080, 1920, 30, 44100

solo, race_a, race_b, work = sys.argv[1:5]
os.makedirs(work, exist_ok=True)
os.makedirs(OUT, exist_ok=True)


def p(name):
    return os.path.join(work, name)


# ---------------------------------------------------------------- graphics
def gradient(top=(38, 198, 186), bottom=(20, 96, 140)):
    im = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    # Faint floating number tiles, like the game backdrop.
    r = random.Random(3)
    tiles = Image.new('RGBA', (W, H))
    td = ImageDraw.Draw(tiles)
    f = ImageFont.truetype(FONT_TITLE, 70)
    for _ in range(18):
        x, y, s = r.randrange(-40, W), r.randrange(-40, H), r.randrange(90, 150)
        td.rounded_rectangle((x, y, x + s, y + s), radius=s // 5, fill=(255, 255, 255, 22), outline=(255, 255, 255, 30), width=3)
        td.text((x + s / 2, y + s / 2 + 4), str(r.randrange(1, 10)), font=f, anchor='mm', fill=(255, 255, 255, 30))
    im = Image.alpha_composite(im.convert('RGBA'), tiles)
    return im


def outlined(d, xy, text, font, fill='white', stroke=(40, 30, 90), sw=8, anchor='mm'):
    d.text(xy, text, font=font, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=stroke)


def caption(lines, size=96, color='white', y=170, sub=None):
    """Transparent full-frame PNG with a big outlined title (and a sub line)."""
    im = Image.new('RGBA', (W, H))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_TITLE, size)
    for i, line in enumerate(lines):
        outlined(d, (W / 2, y + i * size * 1.08), line, f, fill=color)
    if sub:
        fs = ImageFont.truetype(FONT_BODY, 46)
        sy = y + len(lines) * size * 1.08 - size * 0.2
        d.text((W / 2, sy), sub, font=fs, anchor='mm', fill='white', stroke_width=3, stroke_fill=(20, 60, 90))
    return im


def phone_mask(w, h, radius):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    return m


def phone_frame(w, h, radius, x, y, border=10):
    """Shadow + white rim drawn under a phone placed at (x, y)."""
    im = Image.new('RGBA', (W, H))
    sh = Image.new('RGBA', (W, H))
    ImageDraw.Draw(sh).rounded_rectangle((x - border, y - border + 18, x + w + border, y + h + border + 18), radius=radius + border, fill=(0, 30, 50, 110))
    im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(16)))
    ImageDraw.Draw(im).rounded_rectangle((x - border, y - border, x + w + border, y + h + border), radius=radius + border, fill='white')
    return im


def label(text, x, y, fill):
    im = Image.new('RGBA', (W, H))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_TITLE, 54)
    tw = d.textlength(text, font=f)
    d.rounded_rectangle((x - tw / 2 - 30, y - 42, x + tw / 2 + 30, y + 40), radius=40, fill=fill)
    outlined(d, (x, y + 2), text, f, sw=5, stroke=(30, 30, 60))
    return im


def end_card(title_lines, sub):
    im = gradient()
    d = ImageDraw.Draw(im)
    icon = Image.open(ICON).convert('RGBA').resize((360, 360), Image.LANCZOS)
    m = phone_mask(360, 360, 80)
    sh = Image.new('RGBA', (W, H))
    ImageDraw.Draw(sh).rounded_rectangle((360, 470, 720, 830), radius=80, fill=(0, 30, 50, 120))
    im = Image.alpha_composite(im, sh.filter(ImageFilter.GaussianBlur(18)))
    im.paste(icon, (360, 440), m)
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_TITLE, 120)
    for i, line in enumerate(title_lines):
        outlined(d, (W / 2, 960 + i * 128), line, f, sw=10)
    fs = ImageFont.truetype(FONT_BODY, 52)
    d.text((W / 2, 960 + len(title_lines) * 128 + 10), sub, font=fs, anchor='mm', fill='white', stroke_width=3, stroke_fill=(20, 60, 90))
    # "Play free" button
    by = 1420
    d.rounded_rectangle((250, by + 14, 830, by + 174), radius=80, fill=(196, 84, 22))
    d.rounded_rectangle((250, by, 830, by + 160), radius=80, fill=(255, 128, 48))
    d.rounded_rectangle((290, by + 16, 790, by + 50), radius=20, fill=(255, 170, 110))
    outlined(d, (W / 2, by + 86), 'PLAY FREE', ImageFont.truetype(FONT_TITLE, 88), sw=7, stroke=(120, 50, 10))
    fsm = ImageFont.truetype(FONT_BODY, 44)
    d.text((W / 2, by + 260), 'on Google Play', font=fsm, anchor='mm', fill='white')
    return im


# Phone geometry (recordings are 1206x2622).
SRC_W, SRC_H = 1206, 2622
solo_h = 1500
solo_w = round(SRC_W * solo_h / SRC_H) // 2 * 2  # 690
solo_x, solo_y = (W - solo_w) // 2, 360
split_h = 1060
split_w = round(SRC_W * split_h / SRC_H) // 2 * 2  # 488
gap = (W - 2 * split_w) // 3
split_y = 500

gradient().save(p('bg.png'))
phone_mask(solo_w, solo_h, 70).save(p('mask_solo.png'))
phone_mask(split_w, split_h, 54).save(p('mask_split.png'))
phone_frame(solo_w, solo_h, 70, solo_x, solo_y).save(p('frame_solo.png'))
fs = Image.alpha_composite(phone_frame(split_w, split_h, 54, gap, split_y), phone_frame(split_w, split_h, 54, 2 * gap + split_w, split_y))
fs = Image.alpha_composite(fs, label('YOU', gap + split_w / 2, split_y - 70, (124, 58, 237)))
fs = Image.alpha_composite(fs, label('FRIEND', 2 * gap + 1.5 * split_w, split_y - 70, (59, 130, 246)))
fs.save(p('frame_split.png'))

caption(['RELAX WITH', 'SUDOKU'], y=150).save(p('cap_solo1.png'))
caption(['3 STARS.', 'PERFECT!'], color=(255, 214, 64), y=150).save(p('cap_solo2.png'))
caption(['RACE A FRIEND', 'LIVE!'], y=140).save(p('cap_race1.png'))
caption(['WHO FINISHES', 'FIRST?'], color=(255, 214, 64), y=140).save(p('cap_race2.png'))
sub = Image.new('RGBA', (W, H))
ImageDraw.Draw(sub).text((W / 2, 1720), 'Send a 6-digit code. See their progress live.', font=ImageFont.truetype(FONT_BODY, 44), anchor='mm', fill='white', stroke_width=3, stroke_fill=(20, 60, 90))
sub.save(p('sub_race.png'))
caption(['YOU WON!'], size=130, color=(255, 214, 64), y=190).save(p('cap_won.png'))
end_card(['SUDOKU'], 'Play with friends').save(p('end.png'))


# ---------------------------------------------------------------- audio
def read_wav(name):
    with wave.open(os.path.join(SFX, name)) as w:
        n, ch, sw, sr = w.getnframes(), w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(n)
    assert sw == 2, name
    vals = struct.unpack('<%dh' % (len(raw) // 2), raw)
    mono = [sum(vals[i:i + ch]) / ch / 32768 for i in range(0, len(vals), ch)]
    if sr != SR:  # nearest-sample resample is fine for short effects
        mono = [mono[int(i * sr / SR)] for i in range(int(len(mono) * SR / sr))]
    return mono


def music(seconds, bpm=112):
    """A soft marimba loop: I-V-vi-IV in C, with a light kick."""
    out = [0.0] * int(seconds * SR)
    beat = 60 / bpm
    chords = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]]
    def note(t0, midi, dur, amp):
        f = 440 * 2 ** ((midi - 69) / 12)
        for i in range(int(dur * SR)):
            k = int(t0 * SR) + i
            if k >= len(out):
                break
            t = i / SR
            env = math.exp(-t * 6)
            out[k] += amp * env * (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * 4 * f * t) * math.exp(-t * 20))
    b = 0
    while b * beat < seconds:
        ch = chords[(b // 4) % 4]
        t = b * beat
        note(t, ch[b % 3] + 12, beat * 2, 0.10)          # arpeggio
        note(t + beat / 2, ch[(b + 1) % 3] + 12, beat, 0.06)
        if b % 2 == 0:
            note(t, ch[0] - 12, beat * 2, 0.12)          # bass
        for i in range(int(0.12 * SR)):                   # kick
            k = int(t * SR) + i
            if k < len(out):
                tt = i / SR
                out[k] += 0.18 * math.exp(-tt * 30) * math.sin(2 * math.pi * (50 + 80 * math.exp(-tt * 40)) * tt)
        b += 1
    fade = int(0.6 * SR)
    for i in range(fade):
        out[-1 - i] *= i / fade
    return out


def mix(track, sound, at, gain=1.0):
    k0 = int(at * SR)
    for i, v in enumerate(sound):
        if k0 + i < len(track):
            track[k0 + i] += v * gain


def write_wav(path, track):
    peak = max(1e-6, max(abs(v) for v in track))
    scale = min(1.0, 0.9 / peak)
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v * scale)) * 32767)) for v in track))


ticks = [read_wav('tick_%d.wav' % i) for i in range(10)]


GAME_SFX = False  # music only: the ticks and win sounds clashed with it


def audio(seconds, solve_from, solve_to, step, events):
    track = music(seconds)
    if not GAME_SFX:
        return track
    t, i = solve_from, 0
    r = random.Random(5)
    while t < solve_to:
        mix(track, ticks[i % 10], t, 0.55)
        t += step * (0.75 + r.random() * 0.5)
        i += 1
    for name, at, gain in events:
        mix(track, read_wav(name), at, gain)
    return track


# ---------------------------------------------------------------- video
def run(args):
    print(' '.join(args[:6]), '...')
    subprocess.run(['ffmpeg', '-v', 'error', '-y'] + args, check=True)


def seg_phone(src, start, dur, speed, x, y, w, h, mask, frame, caps, out):
    """One segment: gradient bg, frame, the clip (sped up), captions."""
    caps_in = []
    for c in caps:
        caps_in += ['-loop', '1', '-i', c]
    flt = (
        f'[2:v]trim=start={start}:duration={dur * speed},setpts=(PTS-STARTPTS)/{speed},fps={FPS},'
        f'scale={w}:{h}:flags=lanczos,format=rgba[ph];'
        f'[3:v]format=gray[m];[ph][m]alphamerge[phm];'
        f'[0:v][1:v]overlay=0:0[b1];[b1][phm]overlay={x}:{y}[v0]'
    )
    last = 'v0'
    for i in range(len(caps)):
        flt += f';[{last}][{4 + i}:v]overlay=0:0[v{i + 1}]'
        last = f'v{i + 1}'
    run(['-loop', '1', '-i', p('bg.png'), '-loop', '1', '-i', frame, '-i', src, '-loop', '1', '-i', mask] + caps_in +
        ['-filter_complex', flt, '-map', f'[{last}]', '-t', str(dur), '-r', str(FPS), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', out])


def seg_split(start_a, start_b, dur, speed, caps, out):
    caps_in = []
    for c in caps:
        caps_in += ['-loop', '1', '-i', c]
    xa, xb = gap, 2 * gap + split_w
    def ph(idx, start, name):
        return (f'[{idx}:v]trim=start={start}:duration={dur * speed},setpts=(PTS-STARTPTS)/{speed},fps={FPS},'
                f'scale={split_w}:{split_h}:flags=lanczos,format=rgba[{name}r];[{name}r][m{name}]alphamerge[{name}];')
    flt = (f'[4:v]format=gray,split[ma][mb];' + ph(2, start_a, 'a') + ph(3, start_b, 'b') +
           f'[0:v][1:v]overlay=0:0[b1];[b1][a]overlay={xa}:{split_y}[b2];[b2][b]overlay={xb}:{split_y}[v0]')
    last = 'v0'
    for i in range(len(caps)):
        flt += f';[{last}][{5 + i}:v]overlay=0:0[v{i + 1}]'
        last = f'v{i + 1}'
    run(['-loop', '1', '-i', p('bg.png'), '-loop', '1', '-i', p('frame_split.png'), '-i', race_a, '-i', race_b,
         '-loop', '1', '-i', p('mask_split.png')] + caps_in +
        ['-filter_complex', flt, '-map', f'[{last}]', '-t', str(dur), '-r', str(FPS), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', out])


def seg_still(img, dur, out):
    # Gentle zoom-in so the end card isn't frozen.
    run(['-loop', '1', '-i', img, '-filter_complex',
         f"scale=2160:3840,zoompan=z='1+0.0008*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={int(dur * FPS)}:s={W}x{H}:fps={FPS}",
         '-t', str(dur), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', out])


def concat(parts, wav, out):
    lst = p(os.path.basename(out) + '.txt')
    with open(lst, 'w') as f:
        f.writelines(f"file '{x}'\n" for x in parts)
    run(['-f', 'concat', '-safe', '0', '-i', lst, '-i', wav, '-map', '0:v', '-map', '1:a',
         '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-c:a', 'aac', '-b:a', '160k',
         '-shortest', '-movflags', '+faststart', out])


# Solo: solve (clip 15.0-28.4 s at 1.6x), win card (28.4-32.4 s), end card.
seg_phone(solo, 15.0, 8.4, 1.6, solo_x, solo_y, solo_w, solo_h, p('mask_solo.png'), p('frame_solo.png'), [p('cap_solo1.png')], p('s1.mp4'))
seg_phone(solo, 28.4, 4.0, 1.0, solo_x, solo_y, solo_w, solo_h, p('mask_solo.png'), p('frame_solo.png'), [p('cap_solo2.png')], p('s2.mp4'))
seg_still(p('end.png'), 3.0, p('s3.mp4'))
write_wav(p('solo.wav'), audio(15.4, 0.3, 8.2, 0.38 / 1.6, [
    ('win.wav', 8.5, 0.9), ('star_1.wav', 9.3, 0.8), ('star_2.wav', 9.7, 0.8), ('star_3.wav', 10.1, 0.8),
    ('coin.wav', 11.2, 0.7), ('whoosh.wav', 12.3, 0.8)]))
concat([p('s1.mp4'), p('s2.mp4'), p('s3.mp4')], p('solo.wav'), os.path.join(OUT, 'sudoku_solve_15s.mp4'))

# Race: split screen (A 18.8 s / B 18.9 s on, at 2x), A's win (43.0-46.0 s), end card.
seg_split(18.8, 18.9, 6.0, 2.0, [p('cap_race1.png'), p('sub_race.png')], p('r1.mp4'))
seg_split(30.8, 30.9, 6.0, 2.0, [p('cap_race2.png'), p('sub_race.png')], p('r2.mp4'))
seg_phone(race_a, 43.0, 3.0, 1.0, solo_x, solo_y, solo_w, solo_h, p('mask_solo.png'), p('frame_solo.png'), [p('cap_won.png')], p('r3.mp4'))
seg_still(p('end.png'), 3.0, p('r4.mp4'))
write_wav(p('race.wav'), audio(18.4, 0.3, 11.8, 0.38 / 2.0 / 1.6, [
    ('whoosh.wav', 12.0, 0.8), ('win.wav', 12.2, 0.9), ('coin.wav', 13.6, 0.7), ('whoosh.wav', 15.3, 0.8)]))
concat([p('r1.mp4'), p('r2.mp4'), p('r3.mp4'), p('r4.mp4')], p('race.wav'), os.path.join(OUT, 'sudoku_race_18s.mp4'))
print('done')
