
# 🧪 Workshop — EcoIndex & Hébergement Web

## 🎯 Objectif

Montrer, à périmètre constant, comment un hébergement web optimisé côté serveur peut réduire l’impact environnemental (vu via EcoIndex) par rapport à un hébergement “par défaut”.

## ⚙️ Pré-requis

- **Windows + WSL2** (Ubuntu conseillé)
- **Docker Desktop** installé et lancé
- **git** et **curl** disponibles

---

## 🪣 Étapes du lab

### 1️⃣ Récupérer le site (miroir statique)

Un script est fourni dans `scripts/fetch_from_sitemap.sh` :

```bash
./scripts/fetch_from_sitemap.sh https://green-nerds.io ./legacy_website/green-nerds.io
```

À la fin, vous obtenez un dossier `legacy_website/green-nerds.io` contenant les pages HTML, assets, etc.

---

### 2️⃣ Démarrer l’environnement Docker

```bash
docker compose up -d --force-recreate
```

Trois services sont disponibles :
- `eco-origin` → sert le miroir brut (référence)
- `eco-baseline` → Nginx sans optimisations
- `eco-optimized` → Nginx avec compression + cache

Vérifiez qu’ils répondent :
```bash
curl -I http://localhost:8080/
curl -I http://localhost:8081/
curl -I http://localhost:18080/crawl.html
```

---

### 3️⃣ Mesure EcoIndex

> 💡 Le flag `--add-host host.docker.internal:host-gateway` garantit que le conteneur EcoIndex accède bien à votre environnement WSL2 via Docker Desktop.

```bash
# Baseline
mkdir -p reports_baseline
docker run --rm   --add-host host.docker.internal:host-gateway   -v "$PWD/reports_baseline:/tmp/ecoindex-cli"   vvatelot/ecoindex-cli:latest   ecoindex-cli analyze     --url "http://localhost:8080/"     --recursive --no-interaction --html-report --export-format csv

# Optimisé
mkdir -p reports_opt
docker run --rm   --add-host host.docker.internal:host-gateway   -v "$PWD/reports_opt:/tmp/ecoindex-cli"   vvatelot/ecoindex-cli:latest   ecoindex-cli analyze     --url "http://localhost:8081/"     --recursive --no-interaction --html-report --export-format csv
```

Les rapports HTML et CSV seront disponibles dans :
- `./reports_baseline/output/.../index.html`
- `./reports_opt/output/.../index.html`

---

### 4️⃣ Visualiser les rapports

```bash
# Rapports baseline
docker run --rm -p 19080:80   -v "$PWD/reports_baseline/output:/usr/share/nginx/html:ro" nginx:alpine

# (dans un autre terminal)
# Rapports optimisés
docker run --rm -p 19081:80   -v "$PWD/reports_opt/output:/usr/share/nginx/html:ro" nginx:alpine
```

Ouvrez ensuite :
- http://localhost:19080/
- http://localhost:19081/

---

### 5️⃣ Nettoyage

```bash
docker compose down
rm -rf reports_baseline reports_opt
```

---

## 📈 Résultats attendus

| Config | Score moyen | Poids moyen | GES | Eau |
|--------|-------------|-------------|-----|-----|
| Baseline | ~54 | ~2.3 MB | ~1.9 | ~2.8 |
| Optimisée | ~56 | ~1.6 MB | ~1.8 | ~2.7 |

**Gain :** +2 pts EcoIndex (≈ +4 %), obtenu uniquement par gzip + cache côté serveur.

---

## 🧩 Conclusion

Même sans toucher au contenu, la configuration serveur (compression, cache, headers) permet une réduction mesurable de l’impact environnemental.  
Les gains plus forts viendront ensuite des optimisations de contenu (images, JS, lazy-loading…).
