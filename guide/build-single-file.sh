#!/usr/bin/env bash
# Rehberi tek dosyada birleştirir — başka bir ortamdaki AI'a vermek için.
#   ./build-single-file.sh  →  ../IMPLEMENTATION-GUIDE.md
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../IMPLEMENTATION-GUIDE.md"

{
  cat "$HERE/README.md"
  for f in 00-kesif.md 01-olcum.md 02-hizli-kazanimlar.md 03-sicak-webview.md \
           04-auth-ve-veri.md 05-reveal.md 06-kalici-webview.md \
           07-ileri-seviye.md 08-dogrulama.md 09-web-sozlesmesi.md; do
    printf '\n\n---\n\n'
    cat "$HERE/$f"
  done
} > "$OUT"

# Dosyalar arası bağlantıları tek dosyada anlamlı hale getir
python3 - "$OUT" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
TITLES = {
    '00-kesif': 'Faz 0 — Keşif', '01-olcum': 'Faz 1 — Ölçüm',
    '02-hizli-kazanimlar': 'Faz 2 — Hızlı kazanımlar',
    '03-sicak-webview': 'Faz 3 — Sıcak WebView',
    '04-auth-ve-veri': 'Faz 4 — Auth', '05-reveal': 'Faz 5 — Reveal',
    '06-kalici-webview': 'Faz 6 — Kalıcı WebView',
    '07-ileri-seviye': 'Faz 7 — İleri seviye',
    '08-dogrulama': 'Faz 8 — Doğrulama',
    '09-web-sozlesmesi': 'Ek — Web sözleşmesi',
}
def sub(m):
    return '] (bu dosyada: %s bölümü)' % TITLES.get(m.group(1), m.group(1))
s = re.sub(r'\]\((\d\d-[a-z-]+)\.md\)', sub, s)
open(p, 'w').write(s)
print(f"{p}: {len(s.splitlines())} satır, {len(s)//1024} KB")
PY
