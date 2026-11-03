#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Juan Luis (JLPalmes)
set -eu
cd "$(dirname "$0")"
mkdir -p .build PracticasFP.app/Contents/MacOS PracticasFP.app/Contents/Resources
cp LICENSE PracticasFP.app/Contents/Resources/LICENSE
cp AVISO-LICENCIA.txt PracticasFP.app/Contents/Resources/AVISO-LICENCIA.txt
cp Recursos/PracticasFP.icns PracticasFP.app/Contents/Resources/PracticasFP.icns
cat > PracticasFP.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PracticasFP</string>
<key>CFBundleIdentifier</key><string>es.practicasfp.mac</string>
<key>CFBundleName</key><string>Prácticas FP</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.8.4</string>
<key>CFBundleVersion</key><string>184</string>
<key>CFBundleIconFile</key><string>PracticasFP.icns</string>
<key>CFBundleDevelopmentRegion</key><string>es</string>
<key>CFBundleLocalizations</key><array><string>es</string></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
swiftc -target arm64-apple-macosx14.0 -parse-as-library Fuentes/Model.swift Fuentes/DocumentWorkflow.swift Fuentes/Workflow.swift Fuentes/CompanyViews.swift Fuentes/Store.swift Fuentes/Import.swift Fuentes/ImportView.swift Fuentes/Reports.swift Fuentes/Features.swift Fuentes/DocumentViews.swift Fuentes/App.swift -o .build/PracticasFP-arm64 -framework SwiftUI -framework AppKit -module-cache-path .build/cache
cp .build/PracticasFP-arm64 PracticasFP.app/Contents/MacOS/PracticasFP
xattr -d com.apple.FinderInfo PracticasFP.app 2>/dev/null || true
codesign --force --sign - PracticasFP.app
echo "Aplicación compilada."
