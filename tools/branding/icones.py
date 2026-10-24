"""Images d'icône et d'écran de démarrage à partir de l'image du propriétaire.

    python3 -I tools/branding/icones.py

Source : apps/mobile/assets/branding/icone_source.png (fond blanc, carré).
Produit dans le même dossier :
- icone.png : icône complète 1024×1024 (iOS, Android ancien format, web) ;
- icone_premier_plan.png : premier plan de l'icône adaptative Android, motif
  ramené dans la zone sûre (cercle de 66/108 du côté), sur fond blanc ;
- demarrage.png : motif seul pour l'écran de démarrage ;
- demarrage_android12.png : motif dans le cercle central (2/3) imposé par
  Android 12 et plus.
Puis : dart run flutter_launcher_icons && dart run flutter_native_splash:create
et enfin `python3 -I tools/branding/icones.py --apres` : icônes web « maskable »
de l'app refaites depuis le premier plan (le générateur prend l'icône complète,
rognée par le masque rond), icônes du site (favicon, PWA de projection, écran
d'accueil iPhone) et favicon du back-office.
"""

import sys

from pathlib import Path

from PIL import Image

DIR = Path(__file__).resolve().parents[2] / 'apps/mobile/assets/branding'
WHITE = (255, 255, 255)


def load() -> Image.Image:
    im = Image.open(DIR / 'icone_source.png').convert('RGB')
    # Fond presque blanc (253-255) → blanc pur, pour se fondre dans le fond
    # blanc de l'icône adaptative et de l'écran de démarrage.
    return _whiten(im)


def _whiten(im: Image.Image) -> Image.Image:
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r >= 250 and g >= 250 and b >= 250:
                px[x, y] = WHITE
    return im


def motif(im: Image.Image) -> Image.Image:
    """Motif recadré au plus juste (carré centré sur le dessin)."""
    w, h = im.size
    px = im.load()
    xs, ys = [], []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if min(px[x, y]) < 245:
                xs.append(x)
                ys.append(y)
    left, top, right, bottom = min(xs), min(ys), max(xs) + 1, max(ys) + 1
    side = max(right - left, bottom - top)
    cx, cy = (left + right) // 2, (top + bottom) // 2
    canvas = Image.new('RGB', (side, side), WHITE)
    canvas.paste(im.crop((cx - side // 2, cy - side // 2, cx + side - side // 2, cy + side - side // 2)), (0, 0))
    return canvas


def centered(art: Image.Image, size: int, ratio: float) -> Image.Image:
    """[art] réduit à [ratio] du côté, centré sur un carré blanc de [size]."""
    inner = round(size * ratio)
    canvas = Image.new('RGB', (size, size), WHITE)
    resized = art.resize((inner, inner), Image.LANCZOS)
    canvas.paste(resized, ((size - inner) // 2, (size - inner) // 2))
    return canvas


def maskable() -> None:
    web = DIR.parents[1] / 'web/icons'
    fg = Image.open(DIR / 'icone_premier_plan.png').convert('RGB')
    for size in (192, 512):
        fg.resize((size, size), Image.LANCZOS).save(web / f'Icon-maskable-{size}.png', optimize=True)


def sites() -> None:
    apps = DIR.parents[2]
    icon = Image.open(DIR / 'icone.png').convert('RGB')
    for size in (192, 512):
        icon.resize((size, size), Image.LANCZOS).save(
            apps / f'web/public/icons/icon-{size}.png', optimize=True
        )
    icon.resize((180, 180), Image.LANCZOS).save(apps / 'web/src/app/apple-icon.png', optimize=True)
    for app in ('web', 'admin'):
        icon.save(apps / f'{app}/src/app/favicon.ico', sizes=[(16, 16), (32, 32), (48, 48)])


def main() -> None:
    if '--apres' in sys.argv:
        maskable()
        sites()
        return
    art = motif(load())
    centered(art, 1024, 0.86).save(DIR / 'icone.png', optimize=True)
    # Zone sûre : cercle de 66/108 ≈ 61 % ; le motif est rond, 60 % suffit.
    centered(art, 1024, 0.60).save(DIR / 'icone_premier_plan.png', optimize=True)
    art.resize((768, 768), Image.LANCZOS).save(DIR / 'demarrage.png', optimize=True)
    # Android 12 : 1152×1152, seul le cercle central de 768 est visible.
    centered(art, 1152, 0.62).save(DIR / 'demarrage_android12.png', optimize=True)


if __name__ == '__main__':
    main()
