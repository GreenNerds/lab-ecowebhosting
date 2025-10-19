🌱 Atelier EcoIndex — Impact de l’hébergement web
Objectif

Montrer, à contenu identique, comment un hébergement web configuré proprement côté serveur peut améliorer un score EcoIndex et réduire l’impact environnemental d’un site.

L’idée : on ne touche ni au code, ni aux images, ni au CSS/JS — on joue uniquement sur la configuration serveur (compression, cache, headers).

Prérequis

Windows 10 ou 11

WSL2
 avec Ubuntu (ou équivalent)

Docker Desktop
 (support WSL2 activé)

Un peu de ligne de commande

Structure du projet
hosting-ecoindex-workshop/
├── docker-compose.yml
├── nginx/
│   ├── default.conf       # config baseline
│   └── optimized.conf     # config optimisée
├── legacy_website/        # miroir statique du site
├── reports_baseline/      # rapports EcoIndex (baseline)
└── reports_opt/           # rapports EcoIndex (optimisé)

1️⃣ Récupérer un miroir statique du site

Dans WSL :

cd ~
mkdir -p ~/green-nerds/legacy_website
cd ~/green-nerds/legacy_website

# Exemple avec le site Green Nerds
wget --mirror --convert-links --adjust-extension --page-requisites \
     --no-parent https://green-nerds.io/


Créer une petite page crawl.html pour le crawl EcoIndex :

ROOT="$HOME/green-nerds/legacy_website/green-nerds.io"
cd "$ROOT"

cat > crawl.html <<'HTML'
<!doctype html><meta charset="utf-8"><title>Eco hub</title><h1>Eco hub</h1><ul>
HTML

ls -1 *.html | grep -v '^crawl\.html$' | head -n 50 \
| while read -r f; do printf '  <li><a href="/%s">/%s</a></li>\n' "$f" "$f"; done >> crawl.html

echo '</ul>' >> crawl.html

2️⃣ Docker Compose

Créer docker-compose.yml :

version: "3.9"
services:
  origin:
    image: nginx:alpine
    ports: ["18080:80"]
    volumes:
      - ../legacy_website:/usr/share/nginx/html:ro

  web-baseline:
    image: nginx:alpine
    ports: ["8080:80"]
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ../legacy_website:/usr/share/nginx/html:ro

  web-optimized:
    image: nginx:alpine
    ports: ["8081:80"]
    volumes:
      - ./nginx/optimized.conf:/etc/nginx/conf.d/default.conf:ro
      - ../legacy_website:/usr/share/nginx/html:ro

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
  location ~* \.(?:css|js|woff2?|svg|json|ico)$ {
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

4️⃣ Lancer le lab
docker compose up -d --force-recreate


Vérifie que tout répond :

for U in http://localhost:8080/ http://localhost:8081/; do
  printf "%-25s " "$U"; curl -sI "$U" | head -n1; done

5️⃣ Analyse EcoIndex

Créer les dossiers de sortie :

mkdir -p reports_baseline reports_opt


Lancer les analyses :

# Baseline
docker run --rm -v "$PWD/reports_baseline:/tmp/ecoindex-cli" \
  vvatelot/ecoindex-cli:latest \
  ecoindex-cli analyze \
    --url "http://host.docker.internal:8080/crawl.html" \
    --recursive --no-interaction --html-report --export-format csv

# Optimisé
docker run --rm -v "$PWD/reports_opt:/tmp/ecoindex-cli" \
  vvatelot/ecoindex-cli:latest \
  ecoindex-cli analyze \
    --url "http://host.docker.internal:8081/crawl.html" \
    --recursive --no-interaction --html-report --export-format csv


Si host.docker.internal ne passe pas, essaie http://localhost:8080.

6️⃣ Visualiser les rapports
# Baseline
docker run --rm -p 19080:80 -v "$PWD/reports_baseline/output:/usr/share/nginx/html:ro" nginx:alpine
# Optimisé
docker run --rm -p 19081:80 -v "$PWD/reports_opt/output:/usr/share/nginx/html:ro" nginx:alpine


Ouvre :

http://localhost:19080

http://localhost:19081

Résultats typiques
Version	Score	Taille moyenne	Requêtes	GES (g)	Eau (cl)
Baseline	~54	2.35 MB	64	1.92	2.88
Optimisée	~56	1.65 MB	64	1.87	2.81

Gain : +2 à +3 points EcoIndex sans modifier le contenu.
La différence vient principalement de la compression et du cache HTTP.

Ce qu’on montre avec cet atelier

L’hébergement seul (Nginx) peut influencer un score EcoIndex.

Les gains restent modestes mais mesurables.

Les optimisations “contenu” (images, JS, lazy-load…) viendront ensuite.

Le tout est reproductible, local et sans dépendance cloud.

Crédits

Atelier conçu dans le cadre de Green Nerds.
Basé sur EcoIndex CLI
 et Nginx.
Auteur : Loïc Darras — 2025.