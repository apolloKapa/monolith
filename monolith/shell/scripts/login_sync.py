#!/usr/bin/env python3
"""Monolith's login screen follows the desktop. Writes to /var/lib/monolith/login (made by the
installer, owned by you, readable by SDDM; nothing happens without it):
  wallpaper.jpg     the wallpaper, blurred and scaled down (the greeter shows it as it is: no
                    shader, so it looks the same with software rendering)
  face.png          your picture, round
  theme.conf.user   colours, font, light or dark, your login name (the theme's theme.conf.user
                    links here; SDDM reads it over theme.conf)
Called by the shell (core/LoginSync.qml) when any of it changes:
  login_sync.py WALLPAPER AVATAR FONT MODE key=#rrggbb ...
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
k = key_of(wall, 'v1')
if Image and k and not stamp_ok('wallpaper', k):
    try:
        im = ImageOps.exif_transpose(Image.open(wall)).convert('RGB')
        im.thumbnail((1280, 1280), Image.LANCZOS)
        im = im.filter(ImageFilter.GaussianBlur(radius=max(12, im.width // 48)))
        save(im, 'wallpaper.jpg', quality=90)
        stamp('wallpaper', k)
        have_wall = True
    except Exception as e:
        print(f'login_sync: wallpaper: {e}', file=sys.stderr)

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
