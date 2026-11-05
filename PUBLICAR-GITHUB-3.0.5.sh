#!/bin/bash
set -euo pipefail

VERSION="3.0.5"
TAG="v${VERSION}-fix3"
REPO_URL="https://github.com/williamnardelli37-beep/finalnodo.git"
WORK_DIR="${TMPDIR:-/tmp}/NODO-PUBLICAR-${VERSION}-fix3"

printf '\nNODO ${VERSION} — iniciar compilacao limpa\n'
printf 'Repositorio: %s\nTag: %s\n\n' "$REPO_URL" "$TAG"

command -v git >/dev/null 2>&1 || { echo "ERRO: Git nao esta instalado."; exit 1; }

if [ -d "$WORK_DIR/.git" ]; then
  git -C "$WORK_DIR" fetch origin --tags
  git -C "$WORK_DIR" checkout main
  git -C "$WORK_DIR" pull --ff-only origin main
else
  rm -rf "$WORK_DIR"
  git clone --branch main --single-branch "$REPO_URL" "$WORK_DIR"
fi

if git -C "$WORK_DIR" ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "ERRO: a tag $TAG ja existe no GitHub. Nao vou sobrescreve-la."
  exit 1
fi

git -C "$WORK_DIR" tag -a "$TAG" -m "NODO ${VERSION} - compilacao multiplataforma limpa"
git -C "$WORK_DIR" push origin "$TAG"

printf '\nCompilacao solicitada. O GitHub Actions vai gerar somente os tres instaladores.\n'
echo "Acompanhe: https://github.com/williamnardelli37-beep/finalnodo/actions"
echo "Releases: https://github.com/williamnardelli37-beep/finalnodo/releases"
