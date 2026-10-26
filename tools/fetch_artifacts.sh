#!/usr/bin/env bash
# Unduh seluruh artefak riset dari GitHub Release ke direktori lokal.
# Pemakaian: bash fetch_artifacts.sh [tujuan]
set -euo pipefail

REPO="${REPO:-JinzoU-MwM/pubg-offsets-research}"
TAG="${TAG:-v1.0-artifacts}"
DEST="${1:-./artifacts}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI tidak ditemukan. Install dulu: https://cli.github.com/" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh belum login (jalankan: gh auth login)" >&2
  exit 1
fi

mkdir -p "$DEST"
echo "[*] repo=$REPO tag=$TAG dest=$DEST"
gh release download "$TAG" --repo "$REPO" --dir "$DEST" --clobber

if [ -f "$DEST/SHA256SUMS.txt" ]; then
  ( cd "$DEST" && sha256sum -c SHA256SUMS.txt )
else
  echo "[!] SHA256SUMS.txt tidak ada di release" >&2
fi

echo "[*] selesai:"
ls -la "$DEST"
