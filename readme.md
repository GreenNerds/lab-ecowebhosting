# 🌍 Atelier EcoIndex — Impact de l’hébergement web

## Objectif
Montrer, à contenu identique, comment un hébergement web configuré côté serveur peut **améliorer le score EcoIndex** et réduire l’impact environnemental d’un site.  
On agit sur la **config serveur** (compression, cache, headers).

## Prérequis
- Windows 10 / 11
- WSL2 (Ubuntu conseillé)
- Docker Desktop (WSL2 activé)
- Paquets utiles côté WSL :
```bash
sudo apt install -y curl wget file gzip python3 libxml2-utils
```

## Structure
```text
.
├── docker-compose.yml
├── nginx/
│   ├── default.conf
│   └── optimized.conf
├── scripts/
│   └── fetch_from_sitemap.sh
├── legacy_website/
├── reports_baseline/
└── reports_opt/
```

## 1) Récupérer le miroir statique
```bash
chmod +x scripts/fetch_from_sitemap.sh
SITE="https://green-nerds.io"
OUT="./legacy_website/green-nerds.io"
scripts/fetch_from_sitemap.sh "$SITE" "$OUT"
```

Créer la page hub **dans le miroir** :
```bash
ROOT="./legacy_website/green-nerds.io"
cd "$ROOT"

cat > crawl.html <<'HTML'
<!doctype html><meta charset="utf-8"><title>Eco hub</title><h1>Eco hub</h1><ul>
HTML

ls -1 *.html | grep -v '^crawl\.html$' | head -n 50 | while read -r f; do printf '  <li><a href="/%s">/%s</a></li>\n' "$f" "$f"; done >> crawl.html

echo '</ul>' >> crawl.html
```

## 2) Lancer les serveurs
```bash
docker compose up -d --force-recreate
```
Vérifier :
```bash
# Vérifie que les 3 serveurs répondent
for U in \
  http://localhost:8080/crawl.html \
  http://localhost:8081/crawl.html \
  http://localhost:18080/green-nerds.io/crawl.html; do
  printf "%-45s " "$U"; curl -sI "$U" | head -n1
done

```

## 3) Mesure EcoIndex
```bash
mkdir -p reports_baseline reports_opt

# Baseline
docker run --rm   -v "$PWD/reports_baseline:/tmp/ecoindex-cli"   vvatelot/ecoindex-cli:latest   ecoindex-cli analyze     --url "http://host.docker.internal:8080/crawl.html"     --recursive --no-interaction --html-report --export-format csv

# Optimisé
docker run --rm   -v "$PWD/reports_opt:/tmp/ecoindex-cli"   vvatelot/ecoindex-cli:latest   ecoindex-cli analyze     --url "http://host.docker.internal:8081/crawl.html"     --recursive --no-interaction --html-report --export-format csv
```
> Sous WSL, si `host.docker.internal` ne fonctionne pas : utiliser `http://localhost:8080` et `http://localhost:8081`.

## 4) Visualiser les rapports
```bash
# Baseline
docker run --rm -p 19080:80   -v "$PWD/reports_baseline/output:/usr/share/nginx/html:ro" nginx:alpine

# Optimisé
docker run --rm -p 19081:80   -v "$PWD/reports_opt/output:/usr/share/nginx/html:ro" nginx:alpine
```
Puis ouvrir :
- http://localhost:19080  
- http://localhost:19081
