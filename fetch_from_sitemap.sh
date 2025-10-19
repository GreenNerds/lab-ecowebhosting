#!/usr/bin/env bash
set -euo pipefail

SITE="${1:-https://green-nerds.io}"
OUT_DIR="${2:-$HOME/green-nerds/legacy_website/green-nerds.io}"
TMP_DIR="$(mktemp -d -t ecosm-XXXXXX)"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"

echo ">> Site:    $SITE"
echo ">> Out dir: $OUT_DIR"
echo ">> Temp:    $TMP_DIR"
mkdir -p "$OUT_DIR"

extract_locs() {
  local xmlfile="$1"
  if command -v xmllint >/dev/null 2>&1; then
    xmllint --xpath "//*[local-name()='loc']/text()" "$xmlfile" 2>/dev/null \
      | tr ' ' '\n' || true
  else
    python3 - "$xmlfile" <<'PY' || true
import sys, xml.etree.ElementTree as ET
fn = sys.argv[1]
nsfree = lambda tag: tag.split('}',1)[-1] if '}' in tag else tag
tree = ET.parse(fn); root = tree.getroot()
for e in root.iter():
    if nsfree(e.tag) == 'loc' and (e.text or '').strip():
        print(e.text.strip())
PY
  fi
}

CANDS=("$SITE/wp-sitemap.xml" "$SITE/sitemap_index.xml" "$SITE/sitemap.xml")
SITEMAP=""
for sm in "${CANDS[@]}"; do
  if curl -fsSIL -A "$UA" "$sm" >/dev/null; then SITEMAP="$sm"; break; fi
done
[[ -n "$SITEMAP" ]] || { echo "!! Aucun sitemap détecté"; exit 1; }
echo ">> Sitemap détecté: $SITEMAP"

root="$TMP_DIR/root"
curl -fsSL -A "$UA" "$SITEMAP" -o "${root}.raw" || { echo "!! échec DL root"; exit 1; }
file --mime-type "${root}.raw" | grep -q gzip && gunzip -c "${root}.raw" > "${root}.xml" || cp "${root}.raw" "${root}.xml"
grep -qi "<sitemapindex" "${root}.xml" && is_index=1 || is_index=0

ALL_URLS="$TMP_DIR/all_urls.txt"; : > "$ALL_URLS"
if [[ $is_index -eq 1 ]]; then
  echo ">> Type: sitemapindex"
  mapfile -t SUBS < <(extract_locs "${root}.xml")
  echo ">> Sous-sitemaps: ${#SUBS[@]}"
  for sub in "${SUBS[@]}"; do
    [[ -n "$sub" ]] || continue
    fn="$TMP_DIR/$(basename "$sub")"
    curl -fsSL -A "$UA" "$sub" -o "${fn}.raw" || { echo "WARN: fail $sub"; continue; }
    if file --mime-type "${fn}.raw" | grep -q gzip; then
      gunzip -c "${fn}.raw" > "${fn}.xml" || { echo "WARN: gunzip $sub"; continue; }
    else
      cp "${fn}.raw" "${fn}.xml"
    fi
    extract_locs "${fn}.xml" >> "$ALL_URLS"
  done
else
  echo ">> Type: simple sitemap"
  extract_locs "${root}.xml" >> "$ALL_URLS"
fi

# Nettoie CDATA et filtre LARGE (pages du domaine, pas médias, pas wp-json/feed/comments)
HOST=$(echo "$SITE" | awk -F/ '{print $3}')
sed -E 's#^<!\[CDATA\[##; s#\]\]>$##' "$ALL_URLS" \
| awk -v host="$HOST" '
  $0 ~ "^https?://"host {
    if ($0 !~ /\.(png|jpe?g|gif|webp|avif|svg|pdf|zip|mp4|mp3|ico)(\?|$)/ &&
        $0 !~ /(\/wp-json|\/feed|\/comments)(\/|$)/)
      print
  }
' | sort -u > "$TMP_DIR/pages.txt"

CNT=$(wc -l < "$TMP_DIR/pages.txt" || echo 0)
echo ">> Pages retenues: $CNT"
[[ $CNT -gt 0 ]] || { echo "!! 0 page après filtre. Inspecte $ALL_URLS"; exit 2; }
sed -n '1,10p' "$TMP_DIR/pages.txt" | sed 's/^/   - /'

echo ">> Téléchargement des pages + assets (wget)"
while read -r URL; do
  [[ -n "$URL" ]] || continue
  echo "   fetch: $URL"
  wget \
    --user-agent="$UA" \
    --page-requisites \
    --convert-links \
    --adjust-extension \
    --no-parent \
    --directory-prefix="$OUT_DIR" \
    --domains="$HOST" \
    --reject-regex='wp-json|/feed|/comments' \
    --wait=0.2 --random-wait \
    "$URL" >/dev/null 2>&1 || echo "WARN: échec $URL"
done < "$TMP_DIR/pages.txt"

echo ">> Terminé. Dossier: $OUT_DIR"