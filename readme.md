🌍 Atelier EcoIndex — Impact de l’hébergement web
Objectif

Montrer, à contenu identique, comment un hébergement web configuré côté serveur peut améliorer le score EcoIndex et réduire l’impact environnemental d’un site.

L’idée : on ne touche ni au code, ni aux images, ni au CSS/JS — on joue uniquement sur la configuration serveur (compression, cache, headers).

Prérequis

Windows 10/11

WSL2
 (Ubuntu conseillé)

Docker Desktop
 (WSL2 activé)

Paquets côté WSL (Ubuntu) :

sudo apt-get update && sudo apt-get install -y \
  curl wget file gzip python3 libxml2-utils


libxml2-utils fournit xmllint (optionnel mais plus rapide). Le script tombe sinon sur Python xml.etree.

Structure du projet
hosting-ecoindex-workshop/
├── docker-compose.yml
├── nginx/
│   ├── default.conf       # baseline
│   └── optimized.conf     # optimisée
├── scripts/
│   └── fetch_from_sitemap.sh
├── legacy_website/        # miroir statique (généré par le script)
├── reports_baseline/      # rapports EcoIndex (baseline)
└── reports_opt/           # rapports EcoIndex (optimisé)

1️⃣ Récupérer le miroir statique (via sitemap)

Le repo contient scripts/fetch_from_sitemap.sh.
Il détecte le sitemap, liste les pages (hors médias/feed/wp-json) puis télécharge pages + assets.

# Depuis la racine du repo
chmod +x scripts/fetch_from_sitemap.sh

# Exemple : récupérer green-nerds.io dans ./legacy_website/green-nerds.io
SITE="https://green-nerds.io"
OUT="./legacy_website/green-nerds.io"
scripts/fetch_from_sitemap.sh "$SITE" "$OUT"


Le script affiche un récap (sitemap détecté, nb de pages retenues, etc.) et stocke le miroir dans ./legacy_website/green-nerds.io.

Créer une petite page crawl.html (hub pour EcoIndex) dans le dossier du miroir :

ROOT="./legacy_website/green-nerds.io"
cd "$ROOT"

cat > crawl.html <<'HTML'
<!doctype html><meta charset="utf-8"><title>Eco hub</title><h1>Eco hub</h1><ul>
HTML

ls -1 *.html | grep -v '^crawl\.html$' | head -n 50 \
| while read -r f; do printf '  <li><a href="/%s">/%s</a></li>\n' "$f" "$f"; done >> crawl.html

echo '</ul>' >> crawl.html


Astuce : adapte head -n 50 selon la taille du site.

2️⃣ Docker Compose

docker-compose.yml (3 services : origin, web-baseline, web-optimized) :

version: "3.9"
services:
  origin:
    image: nginx:alpine
    container_name: eco-origin
    ports: ["18080:80"]
    volumes:
      - ./legacy_website:/usr/share/nginx/html:ro
    restart: unless-stopped

  web-baseline:
    image: nginx:alpine
    container_name: eco-baseline
    ports: ["8080:80"]
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./legacy_website:/usr/share/nginx/html:ro
    restart: unless-stopped

  web-optimized:
    image: nginx:alpine
    container_name: eco-optimized
    ports: ["8081:80"]
    volumes:
      - ./nginx/optimized.conf:/etc/nginx/conf.d/default.conf:ro
      - ./legacy_website:/usr/share/nginx/html:ro
    restart: unless-stopped

3️⃣ Config Nginx

baseline — nginx/default.conf

server {
  listen 80;
  root /usr/share/nginx/html/green-nerds.io;
  index index.html;

  location / { try_files $uri $uri/ =404; }
}


optimisée — nginx/optimized.conf

server {
  listen 80;
  root /usr/share/nginx/html/green-nerds.io;
  index index.html;

  # Compression texte
  gzip on;
  gzip_comp_level 5;
  gzip_min_length 1024;
  gzip_vary on;
  gzip_types
    text/plain text/css text/javascript application/javascript
    application/json application/xml image/svg+xml
    font/ttf font/otf application/vnd.ms-fontobject;

  # Cache par type
  location ~* \.(?:css|js|woff2?|svg|json|ico|map)$ {
    add_header Cache-Control "public, max-age=31536000, immutable";
    try_files $uri =404;
  }

  location ~* \.(?:png|jpg|jpeg|gif|webp|avif)$ {
    add_header Cache-Control "public, max-age=2592000";
    try_files $uri =404;
  }

  location ~* \.(?:html?)$ {
    add_header Cache-Control "public, max-age=30";
    try_files $uri =404;
  }

  location / { try_files $uri $uri/ =404; }
}

4️⃣ Démarrer
docker compose up -d --force-recreate


Sanity-check :

for U in http://localhost:8080/ http://localhost:8081/ http://localhost:18080/; do
  printf "%-30s " "$U"; curl -sI "$U" | head -n1; done

5️⃣ Mesure EcoIndex (baseline vs optimisé)

Créer les dossiers :

mkdir -p reports_baseline reports_opt


Lancer les analyses (via l’image vvatelot/ecoindex-cli) :

# Baseline
docker run --rm \
  -v "$PWD/reports_baseline:/tmp/ecoindex-cli" \
  vvatelot/ecoindex-cli:latest \
  ecoindex-cli analyze \
    --url "http://host.docker.internal:8080/crawl.html" \
    --recursive --no-interaction --html-report --export-format csv

# Optimisé
docker run --rm \
  -v "$PWD/reports_opt:/tmp/ecoindex-cli" \
  vvatelot/ecoindex-cli:latest \
  ecoindex-cli analyze \
    --url "http://host.docker.internal:8081/crawl.html" \
    --recursive --no-interaction --html-report --export-format csv


Si host.docker.internal ne marche pas dans ton WSL, remplace par http://localhost:8080 et http://localhost:8081.

6️⃣ Visualiser les rapports
# Baseline
docker run --rm -p 19080:80 -v "$PWD/reports_baseline/output:/usr/share/nginx/html:ro" nginx:alpine
# Optimisé
docker run --rm -p 19081:80 -v "$PWD/reports_opt/output:/usr/share/nginx/html:ro" nginx:alpine


Ouvre :

http://localhost:19080

http://localhost:19081

Résultats typiques
Version	Score	Taille moy.	Requêtes	GES (g)	Eau (cl)
Baseline	~54	~2.35 MB	64	1.92	2.88
Optimisée	~56	~1.65 MB	64	1.87	2.81

+2 à +3 points EcoIndex sans modifier le contenu (compression + cache HTTP).

Ce qu’on montre

L’hébergement seul (Nginx) influence des métriques EcoIndex (octets transférés).

Les requêtes ne changent pas (contenu inchangé).

Les gros gains viendront ensuite des optimisations de contenu (hors atelier).

Démo locale, reproductible, indépendante du cloud.

Scripts

scripts/fetch_from_sitemap.sh

Entrées : SITE (URL du site), OUT_DIR (dossier de sortie).

Exemple :

scripts/fetch_from_sitemap.sh "https://green-nerds.io" "./legacy_website/green-nerds.io"


Détails :

Détecte wp-sitemap.xml / sitemap_index.xml / sitemap.xml

Parse via xmllint (ou Python fallback)

Filtre médias/feeds/wp-json

Télécharge pages + assets avec wget (UA desktop, conversions de liens, extensions)

Sortie dans OUT_DIR

Crédits

Atelier Green Nerds.
Outils : EcoIndex CLI & Nginx.
Auteur : Loïc Darras — 2025.