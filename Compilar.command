#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Juan Luis (JLPalmes)
set -eu
cd "$(dirname "$0")"
# macOS releases can advance independently of Windows.
version=${PRACTICASFP_MAC_VERSION:-2.1.13}
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "Versión de Mac no válida." >&2; exit 1; }
mkdir -p .build PracticasFP.app/Contents/MacOS PracticasFP.app/Contents/Resources
cp LICENSE PracticasFP.app/Contents/Resources/LICENSE
cp AVISO-LICENCIA.txt PracticasFP.app/Contents/Resources/AVISO-LICENCIA.txt
cp Recursos/PracticasFP.icns PracticasFP.app/Contents/Resources/PracticasFP.icns
cat > PracticasFP.app/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PracticasFP</string>
<key>CFBundleIdentifier</key><string>es.practicasfp.mac</string>
<key>CFBundleName</key><string>Prácticas FP</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${version}</string>
<key>CFBundleVersion</key><string>${version}</string>
<key>CFBundleIconFile</key><string>PracticasFP.icns</string>
<key>CFBundleDevelopmentRegion</key><string>es</string>
<key>CFBundleLocalizations</key><array><string>es</string></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
sparkle_flags=()
plist=PracticasFP.app/Contents/Info.plist
framework=PracticasFP.app/Contents/Frameworks/Sparkle.framework
# Remove the previously bundled framework when switching to a development build.
if [[ -d "$framework" ]]; then rm -rf -- "$framework"; fi
if [[ -n "${PRACTICASFP_SPARKLE_DIR:-}" ]]; then
    : "${PRACTICASFP_SPARKLE_PUBLIC_KEY:?Falta la clave pública de Sparkle}"
    feed="${PRACTICASFP_SPARKLE_FEED:-https://github.com/JLPalmes/practicas-fp-publico/releases/download/actualizaciones-mac/appcast.xml}"
    [[ "$feed" == https://* ]] || { echo "El catálogo debe utilizar HTTPS." >&2; exit 1; }
    mkdir -p "${framework:h}"
    ditto "$PRACTICASFP_SPARKLE_DIR/Sparkle.framework" "$framework"
    plutil -insert SUFeedURL -string "$feed" "$plist"
    plutil -insert SUPublicEDKey -string "$PRACTICASFP_SPARKLE_PUBLIC_KEY" "$plist"
    plutil -insert SUEnableAutomaticChecks -bool YES "$plist"
    plutil -insert SUAllowsAutomaticUpdates -bool NO "$plist"
    plutil -insert SUScheduledCheckInterval -integer 86400 "$plist"
    plutil -insert SUScheduledImpatientCheckInterval -integer 86400 "$plist"
    plutil -insert SUVerifyUpdateBeforeExtraction -bool YES "$plist"
    plutil -insert SURequireSignedFeed -bool YES "$plist"
    plutil -insert SUSignedFeedFailureExpirationInterval -integer 0 "$plist"
    sparkle_flags=(-D ACTUALIZACIONES -F "${framework:h}" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks)
fi
swiftc "${sparkle_flags[@]}" -target arm64-apple-macosx14.0 -parse-as-library Fuentes/Model.swift Fuentes/Format5.swift Fuentes/DocumentWorkflow.swift Fuentes/Workflow.swift Fuentes/CompanyViews.swift Fuentes/Store.swift Fuentes/Import.swift Fuentes/ImportView.swift Fuentes/Reports.swift Fuentes/Features.swift Fuentes/DocumentViews.swift Fuentes/App.swift -o .build/PracticasFP-arm64 -framework SwiftUI -framework AppKit -module-cache-path .build/cache
cp .build/PracticasFP-arm64 PracticasFP.app/Contents/MacOS/PracticasFP
xattr -d com.apple.FinderInfo PracticasFP.app 2>/dev/null || true
codesign --force --sign - PracticasFP.app
echo "Aplicación compilada."
