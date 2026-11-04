"""Builds framed store screenshots (1080x1920) from screenshots/*.png.
Run: python3 assets/branding/store_frame.py  (needs Playwright/Chromium)."""
import json, os, subprocess, pathlib
here = pathlib.Path(__file__).resolve().parent
fonts = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts'
shots = [
  ('1_rezepte', 'Was kann ich heute kochen?', 'BaCo zeigt, was dein Vorrat hergibt –<br>Bald-Ablaufendes zuerst.'),
  ('2_rezept', 'Alles beim Rezept', 'Portionen anpassen, Vorrat prüfen,<br>Allergien im Blick.'),
  ('3_kochmodus', 'Kochen Schritt für Schritt', 'Timer direkt aus dem Rezept –<br>auch bei geschlossener App.'),
  ('4_wochenplan', 'Die Woche planen', 'Mit Rezepten und Gerichten<br>aus dem Tiefkühler.'),
  ('5_einkauf', 'Gemeinsam einkaufen', 'Eine Liste für den ganzen Haushalt,<br>nach Abteilungen sortiert.'),
  ('6_vorrat', 'Vorrat im Griff', 'Ablaufdaten, Mindestbestand<br>und Barcode-Scan.'),
]
tpl = """<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{{font-family:R;src:url(file://{fonts}/Roboto-Bold.ttf);font-weight:700}}
@font-face{{font-family:R;src:url(file://{fonts}/Roboto-Regular.ttf);font-weight:400}}
html,body{{margin:0;width:1080px;height:1920px;overflow:hidden}}
body{{background:linear-gradient(160deg,#5E9145 0%,#3F6E30 55%,#2A4F20 100%);font-family:R;color:#fff;text-align:center}}
h1{{font-size:76px;font-weight:700;margin:110px 40px 0;line-height:1.1;letter-spacing:-1px}}
p{{font-size:40px;margin:28px 40px 0;line-height:1.35;color:#E3EFD9}}
.phone{{position:absolute;left:50%;top:430px;transform:translateX(-50%);width:720px;height:1280px;
  padding:16px;background:#1b1f19;border-radius:64px;box-shadow:0 30px 80px rgba(0,0,0,.45)}}
.phone img{{width:720px;height:1280px;border-radius:48px;display:block}}
</style></head><body><h1>{title}</h1><p>{sub}</p>
<div class="phone"><img src="file://{img}"></div></body></html>"""
jobs = []
for name, title, sub in shots:
    html = here / 'store' / f'{name}.html'
    html.write_text(tpl.format(fonts=fonts, title=title, sub=sub, img=here / 'screenshots' / f'{name}.png'))
    jobs.append([str(html), str(here / 'store' / f'{name}.png')])
js = """
const { chromium } = require('playwright');
(async () => {
  const jobs = JSON.parse(process.argv[1]);
  const b = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  for (const [src, out] of jobs) {
    await p.goto('file://' + src, { waitUntil: 'networkidle' });
    await p.screenshot({ path: out });
  }
  await b.close();
})();
"""
subprocess.run(['node', '-e', js, json.dumps(jobs)], check=True)
for j in jobs: os.remove(j[0])
