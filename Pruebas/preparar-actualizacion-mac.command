#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
set -eu
cd "${0:a:h}/.."
: "${PRACTICASFP_SPARKLE_DIR:?Indica la ruta a la distribución de Sparkle}"
: "${PRACTICASFP_SPARKLE_FEED:?Indica la URL HTTPS del catálogo de pruebas}"
export PRACTICASFP_SPARKLE_DIR="${PRACTICASFP_SPARKLE_DIR:a}"
export PRACTICASFP_SPARKLE_FEED
# The temporary test key is for these two builds only.
prueba="$(mktemp -d)"
trap 'rm -rf -- "$prueba"' EXIT
chmod 700 "$prueba"
cat > "$prueba/clave.swift" <<'SWIFT'
import CryptoKit
import Foundation
let key = Curve25519.Signing.PrivateKey()
try key.rawRepresentation.base64EncodedString().write(
    toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
print(key.publicKey.rawRepresentation.base64EncodedString())
SWIFT
PRACTICASFP_SPARKLE_PUBLIC_KEY="$(swift -module-cache-path "$prueba/cache" "$prueba/clave.swift" "$prueba/ed25519")"
export PRACTICASFP_SPARKLE_PUBLIC_KEY
mkdir -p .build
salida="$(mktemp -d "$PWD/.build/prueba-mac.XXXXXX")"
mkdir "$salida/update"
PRACTICASFP_MAC_VERSION=2.1.98 ./Compilar.command
ditto -c -k --keepParent PracticasFP.app "$salida/PracticasFP-2.1.98-arm64.zip"
PRACTICASFP_MAC_VERSION=2.1.99 ./Compilar.command
codesign --verify --deep --strict PracticasFP.app
paquete="$salida/update/PracticasFP-2.1.99-arm64.zip"
ditto -c -k --keepParent PracticasFP.app "$paquete"
cat > "${paquete:r}.md" <<'NOTAS'
Actualización de prueba para comprobar la conservación de datos ficticios.
NOTAS
herramientas="$PRACTICASFP_SPARKLE_DIR/bin"
"$herramientas/generate_appcast" --ed-key-file "$prueba/ed25519" \
    --download-url-prefix "${PRACTICASFP_SPARKLE_FEED%/*}/" \
    --embed-release-notes --maximum-deltas 0 "$salida/update"
"$herramientas/sign_update" --ed-key-file "$prueba/ed25519" --verify "$salida/update/appcast.xml"
firma="$("$herramientas/sign_update" --ed-key-file "$prueba/ed25519" -p "$paquete")"
"$herramientas/sign_update" --ed-key-file "$prueba/ed25519" --verify "$paquete" "$firma"
cp "$paquete" "$prueba/alterado.zip"
echo 'paquete alterado' >> "$prueba/alterado.zip"
if "$herramientas/sign_update" --ed-key-file "$prueba/ed25519" --verify "$prueba/alterado.zip" "$firma"; then
    echo "Se aceptó un paquete alterado." >&2
    exit 1
fi
echo "Compilaciones de prueba y catálogo preparados en $salida"
