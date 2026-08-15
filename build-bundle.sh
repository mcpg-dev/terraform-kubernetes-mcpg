#!/usr/bin/env bash
# Package the terraform-mcpg module suite into dist/iac/terraform/ as a
# self-contained bundle: the modules + the vendored CRD snapshot (so a
# published consumer needs neither the upstream codegen tree nor a live
# cluster to `init`). The publish script (milestone T4) tars this and pushes
# to the Terraform + OpenTofu registries.
set -euo pipefail
WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$WS"

OUT="dist/iac/terraform"
rm -rf "$OUT"
mkdir -p "$OUT"

cp -r iac/terraform/modules "$OUT/modules"
cp -r iac/terraform/examples "$OUT/examples"
cp iac/terraform/README.md "$OUT/README.md" 2>/dev/null || true
# Root module (main/variables/outputs.tf) — the common-case entry point.
cp iac/terraform/*.tf "$OUT/" 2>/dev/null || true

# Vendor the CRD snapshot INTO the crds module so the bundle is self-contained.
mkdir -p "$OUT/modules/crds/crds"
cp iac/codegen/schemas/v1alpha1/crds/*.yaml "$OUT/modules/crds/crds/"

echo "bundled terraform-mcpg → $OUT ($(find "$OUT" -type f | wc -l) files)"
