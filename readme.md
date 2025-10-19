# 🌍 Atelier EcoIndex — Impact de l’hébergement web

> Objectif “hébergement only” : comparer **baseline** vs **optimisé** avec le **même contenu**.
> On agit sur la config serveur (compression, cache, headers), pas sur le site.

## Prérequis
- Windows 10/11 + WSL2 (Ubuntu conseillé)
- Docker Desktop (WSL2 activé)
- Paquets utiles côté WSL :
```bash
sudo apt update && sudo apt install -y curl wget file gzip python3 libxml2-utils
