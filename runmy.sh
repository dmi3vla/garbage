#!/bin/sh
set -e

STAGE3_TAR="$1"
TARGET_PY_VER="$2"
DEST_DIR="${3:-/}"

if [ -z "$STAGE3_TAR" ] || [ -z "$TARGET_PY_VER" ]; then
    echo "Usage: $0 <stage3.tar.xz> <python-version> [destination-root]"
    echo "Example: $0 stage3-amd64-systemd.tar.xz 3.11 /"
    exit 1
fi

WORKDIR="$(mktemp -d)"
echo "[*] Using temporary directory: $WORKDIR"

echo "[*] Extracting stage3..."
tar xpvf "$STAGE3_TAR" -C "$WORKDIR" --xattrs-include='*.*' --numeric-owner

PY_BIN_PATH="$WORKDIR/usr/bin/python${TARGET_PY_VER}"
PY_LIB_PATH="$WORKDIR/usr/lib/python${TARGET_PY_VER}"

if [ ! -f "$PY_BIN_PATH" ]; then
    echo "[-] Python binary not found: $PY_BIN_PATH"
    exit 1
fi

if [ ! -d "$PY_LIB_PATH" ]; then
    echo "[-] Python library directory not found: $PY_LIB_PATH"
    exit 1
fi

echo "[+] Copying python binary..."
cp "$PY_BIN_PATH" "$DEST_DIR/usr/bin/"

echo "[+] Copying python stdlib..."
mkdir -p "$DEST_DIR/usr/lib/python${TARGET_PY_VER}"
cp -r "$PY_LIB_PATH/"* "$DEST_DIR/usr/lib/python${TARGET_PY_VER}/"

echo "[*] Checking eselect availability..."
if command -v eselect >/dev/null 2>&1; then
    echo "[+] Updating eselect python..."
    eselect python update
else
    echo "[!] eselect not found, skipping default python switch."
fi
echo "[*] Cleaning up..."
rm -rf "$WORKDIR"
echo "[✓] Python ${TARGET_PY_VER} successfully extracted and installed."
