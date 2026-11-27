#!/usr/bin/env python3
"""Monolith's login screen follows the desktop. Writes to /var/lib/monolith/login (made by the
installer, owned by you, readable by SDDM; nothing happens without it):
  wallpaper.jpg     the wallpaper, blurred and scaled down (the greeter shows it as it is: no
                    shader, so it looks the same with software rendering)
  face.png          your picture, round
  theme.conf.user   colours, font, light or dark, your login name (the theme's theme.conf.user
                    links here; SDDM reads it over theme.conf)
  wallpaper-mono.jpg  the same in greys (the Monochrome look)
  backdrop.jpg      soft light in your colours (the Colours look); backdrop-black.jpg (Black)
Called by the shell (core/LoginSync.qml) when any of it changes:
  login_sync.py WALLPAPER AVATAR FONT MODE key=#rrggbb ... look=LOOK animated=true|false
LOOK (Settings, or the installer's login screen menu): wallpaper, mono, colours or black.
WALLPAPER is a still picture (a live one's frame). Work already done is skipped (a stamp per part)."""
import os, sys, pwd, subprocess

D = os.environ.get('MONOLITH_LOGIN_DIR', '/var/lib/monolith/login')
if not os.path.isdir(D) or not os.access(D, os.W_OK):
    sys.exit(0)
try:
    from PIL import Image, ImageFilter, ImageOps, ImageDraw
except ImportError:
    Image = None

args = sys.argv[1:] + [''] * 4
wall, avatar, font, mode = args[:4]
colors = dict(a.split('=', 1) for a in args[4:] if '=' in a)
wall = wall[7:] if wall.startswith('file://') else wall
avatar = avatar[7:] if avatar.startswith('file://') else avatar


def stamp_ok(name, key):
    try:
        return open(f'{D}/.{name}.stamp').read() == key
    except OSError:
        return False


def stamp(name, key):
    with open(f'{D}/.{name}.stamp', 'w') as f:
        f.write(key)


def key_of(path, *extra):
    try:
        st = os.stat(path)
    except OSError:
        return ''
    return '|'.join([path, str(st.st_mtime_ns), str(st.st_size), *extra])


def save(img, name, **kw):
    tmp = f'{D}/.{name}.tmp'
    img.save(tmp, format='PNG' if name.endswith('.png') else 'JPEG', **kw)
    os.chmod(tmp, 0o644)
    os.replace(tmp, f'{D}/{name}')


# the wallpaper, blurred: scaled to 1280 across (blurred, more pixels show nothing), the blur as
# strong as the lock screen's
have_wall = os.path.exists(f'{D}/wallpaper.jpg')
k = key_of(wall, 'v2')
if Image and k and not stamp_ok('wallpaper', k):
    try:
        im = ImageOps.exif_transpose(Image.open(wall)).convert('RGB')
        im.thumbnail((1280, 1280), Image.LANCZOS)
        im = im.filter(ImageFilter.GaussianBlur(radius=max(12, im.width // 48)))
        save(im, 'wallpaper.jpg', quality=90)
        # (Monochrome: in greys, a touch darker and flatter so the white text stays clear)
        save(ImageOps.autocontrast(ImageOps.grayscale(im), cutoff=2).point(lambda v: int(v * 0.82)).convert('RGB'), 'wallpaper-mono.jpg', quality=90)
        stamp('wallpaper', k)
        have_wall = True
    except Exception as e:
        print(f'login_sync: wallpaper: {e}', file=sys.stderr)

# your colours as soft light: a few big glows of the accent and its neighbours over the background,
# blurred together (Colours); the same, dim, over black (Black). Small and blurred: shown scaled up
def hexrgb(v, d):
    v = colors.get(v, d)
    try:
        return tuple(int(v[i:i + 2], 16) for i in (1, 3, 5))
    except Exception:
        return tuple(int(d[i:i + 2], 16) for i in (1, 3, 5))


def backdrop(base, glows, strength):
    im = Image.new('RGB', (480, 270), base)
    d = ImageDraw.Draw(im, 'RGBA')
    for (cx, cy, r, col) in glows:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col + (int(255 * strength),))
    return im.filter(ImageFilter.GaussianBlur(radius=60)).resize((1280, 720), Image.BICUBIC)


ck = '|'.join(colors.get(n, '') for n in ('primary', 'accent2', 'accent3', 'surface')) + '|v2'
have_backdrop = os.path.exists(f'{D}/backdrop.jpg')
if Image and not stamp_ok('backdrop', ck):
    try:
        a1, a2, a3 = hexrgb('primary', '#c6bfff'), hexrgb('accent2', '#4a4372'), hexrgb('accent3', '#3d3a56')
        surf = hexrgb('surface', '#131318')
        glows = [(90, 70, 95, a1), (400, 80, 110, a2), (260, 250, 120, a3), (440, 245, 60, a1)]
        save(backdrop(surf, glows, 0.6), 'backdrop.jpg', quality=92)
        save(backdrop((4, 4, 6), [(130, 230, 170, a1), (380, 40, 120, a2)], 0.32), 'backdrop-black.jpg', quality=92)
        stamp('backdrop', ck)
        have_backdrop = True
    except Exception as e:
        print(f'login_sync: backdrop: {e}', file=sys.stderr)

# your picture, round (the greeter has no mask to round it with)
have_face = os.path.exists(f'{D}/face.png')
k = key_of(avatar, 'v1')
if Image and k and not stamp_ok('face', k):
    try:
        im = ImageOps.fit(ImageOps.exif_transpose(Image.open(avatar)).convert('RGBA'), (512, 512), Image.LANCZOS)
        mask = Image.new('L', (2048, 2048), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, 2047, 2047), fill=255)
        im.putalpha(mask.resize((512, 512), Image.LANCZOS))
        save(im, 'face.png')
        stamp('face', k)
        have_face = True
    except Exception as e:
        print(f'login_sync: picture: {e}', file=sys.stderr)
elif not k and have_face:
    os.remove(f'{D}/face.png')
    have_face = False


# the font, only when SDDM can see it (installed for everyone, not only in your home)
def system_font(name):
    if not name:
        return ''
    try:
        out = subprocess.run(['fc-list', '--format', '%{family}\t%{file}\n'], capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return ''
    home = os.path.expanduser('~')
    for line in out.splitlines():
        fams, _, path = line.partition('\t')
        if name in [f.strip() for f in fams.split(',')] and not path.startswith(home):
            return name
    return ''


lines = ['[General]', f'mode={"light" if mode == "light" else "dark"}', f'user={pwd.getpwuid(os.getuid()).pw_name}']
f = system_font(font)
if f:
    lines.append(f'font={f}')
if have_wall:
    lines.append(f'background={D}/wallpaper.jpg')
    if os.path.exists(f'{D}/wallpaper-mono.jpg'):
        lines.append(f'backgroundMono={D}/wallpaper-mono.jpg')
if have_backdrop:
    lines.append(f'backdrop={D}/backdrop.jpg')
    lines.append(f'backdropBlack={D}/backdrop-black.jpg')
look = colors.get('look', 'wallpaper')
lines.append(f'look={look if look in ("wallpaper", "mono", "colours", "black") else "wallpaper"}')
lines.append(f'animated={"false" if colors.get("animated") == "false" else "true"}')
if have_face:
    lines.append(f'face={D}/face.png')
for name in ('primary', 'onPrimary', 'surface', 'onSurface', 'onSurfaceVariant', 'container', 'error', 'outline'):
    v = colors.get(name, '')
    if len(v) == 7 and v.startswith('#'):
        lines.append(f'{name}={v}')
text = '\n'.join(lines) + '\n'
try:
    old = open(f'{D}/theme.conf.user').read()
except OSError:
    old = ''
if text != old:
    tmp = f'{D}/.theme.conf.user.tmp'
    with open(tmp, 'w') as fh:
        fh.write(text)
    os.chmod(tmp, 0o644)
    os.replace(tmp, f'{D}/theme.conf.user')
