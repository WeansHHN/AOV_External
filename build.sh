#!/usr/bin/env bash
set -eu

# ===== THEOS PATH (Rootless) =====
if [ -z "${THEOS:-}" ] && [ -d "/var/mobile/theos" ]; then
	export THEOS="/var/mobile/theos"
fi

# ===== fallback (optional) =====
if [ -z "${THEOS:-}" ] && [ -d "/opt/theos" ]; then
	export THEOS="/opt/theos"
fi

if [ -z "${THEOS:-}" ]; then
	echo "[-] THEOS not found"
	exit 1
fi

APP_NAME="PastaWare"

echo "[*] THEOS: $THEOS"
echo "[*] Cleaning..."

make clean

echo "[*] Building..."

make package FINALPACKAGE=1

# ===== find app =====
APP_PATH=$(find .theos/obj -type d -name "${APP_NAME}.app" 2>/dev/null | head -n 1)

if [ -z "$APP_PATH" ]; then
	echo "[-] ${APP_NAME}.app not found"
	exit 1
fi

echo "[*] App found: $APP_PATH"

# ===== create tipa =====
rm -rf Payload
mkdir -p Payload

cp -R "$APP_PATH" Payload/

OUTPUT="${APP_NAME}.tipa"

rm -f "$OUTPUT"

zip -r "$OUTPUT" Payload >/dev/null

rm -rf Payload

mkdir -p packages
mv "$OUTPUT" packages/

echo "[+] Done"
echo "[+] Output: packages/$OUTPUT"