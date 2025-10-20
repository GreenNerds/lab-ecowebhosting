# Workshop — Hébergement Web & EcoIndex

## Objectif

Comparer deux configurations Nginx :
- une version "baseline" sans optimisation,
- une version "optimisée" (gzip + cache).

---

## Pré-requis

- Windows avec WSL2 (Ubuntu recommandé)
- Docker Desktop installé et démarré
- `git` et `curl` disponibles dans WSL

---

## Étapes du lab

### 1. Cloner le repo Github du lab

Le repo est ici : https://github.com/GreenNerds/lab-ecowebhosting

Commande :

```bash
git clone git@github.com:GreenNerds/lab-ecowebhosting.git
```

### 2. Récupération du site (miroir statique)

Un script est fourni dans `scripts/fetch_from_sitemap.sh`.

Exemple :

```bash
./scripts/fetch_from_sitemap.sh https://green-nerds.io ./legacy_website/green-nerds.io
```

Le dossier `legacy_website/green-nerds.io` contient ensuite les pages HTML et leurs assets.

---

### 3. Génération du fichier `crawl.html`

EcoIndex analyse les liens internes d’un site.  
Pour que le crawl fonctionne correctement, il faut créer une page qui liste les URLs à parcourir :

```bash
ROOT="./legacy_website/green-nerds.io"
cd "$ROOT"

cat > crawl.html <<'HTML'
<!doctype html><meta charset="utf-8"><title>Eco hub</title><h1>Eco hub</h1><ul>
HTML

# Liste des pages à inclure dans le crawl (ajuster selon le site)
ls -1 *.html | grep -v '^crawl\.html$' | head -n 50 |
while read -r f; do
  printf '  <li><a href="/%s">/%s</a></li>\n' "$f" "$f"
done >> crawl.html

echo '</ul>' >> crawl.html
```

Cette page sera accessible sur :  
`http://localhost:18080/crawl.html` (via le service `eco-origin`).

---

### 4. Lancement de l’environnement

```bash
docker compose up -d --force-recreate
```

Trois services sont démarrés :
- `eco-origin` → le miroir brut (référence)
- `eco-baseline` → Nginx sans optimisation
- `eco-optimized` → Nginx avec compression et cache

Vérifiez qu’ils répondent :

```bash
curl -I http://localhost:8080/
curl -I http://localhost:8081/
curl -I http://localhost:18080/crawl.html
```

---

### 5. Mesure EcoIndex

Le flag `--add-host host.docker.internal:host-gateway` permet au conteneur EcoIndex d’accéder à l’environnement WSL2.

```bash
# Baseline
mkdir -p reports_baseline
docker run --rm   --add-host host.docker.internal:host-gateway   -v "$PWD/reports_baseline:/tmp/ecoindex-cli"   vvatelot/ecoindex-cli:latest   ecoindex-cli analyze     --url "http://localhost:8080/"     --recursive --no-interaction --html-report --export-format csv

# Optimisé
mkdir -p reports_opt
docker run --rm   --add-host host.docker.internal:host-gateway   -v "$PWD/reports_opt:/tmp/ecoindex-cli"   vvatelot/ecoindex-cli:latest   ecoindex-cli analyze     --url "http://localhost:8081/"     --recursive --no-interaction --html-report --export-format csv
```

Les rapports sont générés dans :
- `reports_baseline/output/.../index.html`
- `reports_opt/output/.../index.html`

---

### 6. Visualisation des rapports

```bash
# Rapport baseline
docker run --rm -p 19080:80   -v "$PWD/reports_baseline/output:/usr/share/nginx/html:ro" nginx:alpine

# Rapport optimisé
docker run --rm -p 19081:80   -v "$PWD/reports_opt/output:/usr/share/nginx/html:ro" nginx:alpine
```

Ensuite, ouvrez dans le navigateur :
- http://localhost:19080/
- http://localhost:19081/

---

### 7. Nettoyage

```bash
docker compose down
rm -rf reports_baseline reports_opt
```

---

## Conclusion

Même sans modifier le contenu (HTML, images, JS…), un hébergement configuré proprement améliore déjà le score EcoIndex.  
Les gains plus importants viendront ensuite de l’optimisation du contenu (images, lazy loading, CSS critique, etc.).
