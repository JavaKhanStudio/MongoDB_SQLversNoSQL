#!/usr/bin/env bash
# Rend chaque sujets/*/*.svg (schema.svg, et modele.svg sur la branche correction) en PNG (Chrome headless) pour le relire.
#   tools/rendre_png.sh [dossier_sortie]   (defaut : $TMPDIR/sqlnosql-rendu, hors depot)
set -euo pipefail
cd "$(dirname "$0")/.."
sortie="${1:-${TMPDIR:-/tmp}/sqlnosql-rendu}"; mkdir -p "$sortie"
for f in sujets/*/*.svg; do
  n=$(basename "$(dirname "$f")")-$(basename "$f" .svg)
  w=$(grep -o 'width="[0-9]*"' "$f" | head -1 | tr -dc 0-9)
  h=$(grep -o 'height="[0-9]*"' "$f" | head -1 | tr -dc 0-9)
  for theme in light dark; do
    google-chrome --headless=new --disable-gpu --hide-scrollbars \
      --force-device-scale-factor=1.5 --window-size="$w,$h" \
      --blink-settings=preferredColorScheme=$([ $theme = dark ] && echo 0 || echo 1) \
      --screenshot="$sortie/$n-$theme.png" "file://$PWD/$f" 2>/dev/null
  done
  echo "  $sortie/$n-{light,dark}.png"
done
