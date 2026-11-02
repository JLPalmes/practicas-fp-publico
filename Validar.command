#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Juan Luis (JLPalmes)
set -eu
cd "$(dirname "$0")"
task_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/practicas-fp-validacion.XXXXXX")
trap 'rm -rf "$task_validation_dir"' EXIT
common=(Fuentes/Model.swift Fuentes/DocumentWorkflow.swift Fuentes/Workflow.swift Fuentes/Store.swift Fuentes/Import.swift)
python3 Fuentes/TestFixtures.py "$task_validation_dir/fixtures"
for suite in Tests WorkflowTests ImportTests; do
    swiftc -parse-as-library "${common[@]}" "Fuentes/$suite.swift" -o "$task_validation_dir/$suite" -module-cache-path "$task_validation_dir/cache"
    case "$suite" in
        Tests) "$task_validation_dir/$suite" "$task_validation_dir/store" ;;
        WorkflowTests) "$task_validation_dir/$suite" "$task_validation_dir/workflow-store" ;;
        ImportTests) "$task_validation_dir/$suite" "$task_validation_dir/fixtures" ;;
        *) "$task_validation_dir/$suite" ;;
    esac
done
cat > "$task_validation_dir/ViewSupport.swift" <<'SWIFT'
import SwiftUI
typealias LocalState<Value> = SwiftUI.State<Value>
SWIFT
swiftc -parse-as-library "${common[@]}" Fuentes/Reports.swift Fuentes/Features.swift "$task_validation_dir/ViewSupport.swift" Fuentes/FeatureTests.swift -o "$task_validation_dir/FeatureTests" -module-cache-path "$task_validation_dir/cache"
if [[ -n "${PRACTICAS_FP_QA_OUTPUT:-}" ]]; then
    "$task_validation_dir/FeatureTests" "$task_validation_dir/features-store" "$PRACTICAS_FP_QA_OUTPUT"
else
    "$task_validation_dir/FeatureTests" "$task_validation_dir/features-store"
fi
swiftc -typecheck -parse-as-library "${common[@]}" Fuentes/CompanyViews.swift Fuentes/ImportView.swift Fuentes/Reports.swift Fuentes/Features.swift Fuentes/DocumentViews.swift Fuentes/App.swift -module-cache-path "$task_validation_dir/cache"
echo "Pruebas y comprobación de interfaz superadas."
