# modules/crds — apply the MCPG CRDs as first-class, server-side-applied
# resources so they upgrade INDEPENDENTLY of the operator Helm release.
#
# Helm's chart `crds/` directory is install-only — `helm upgrade` never
# touches it — the central install hazard. By managing the
# CRDs here (with `crd.install=false` on the operator chart) a CRD schema
# change becomes a normal `apply`, closing that gap.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

locals {
  # Default to the CRDs vendored into the module (build-bundle copies the
  # snapshot here). Callers in-repo pass the codegen snapshot path explicitly.
  dir = coalesce(var.crds_dir, "${path.module}/crds")
  # One split-by-kind CRD YAML per file (crdgen --split-by-kind output).
  crd_files = tolist(fileset(local.dir, "*.yaml"))
}

resource "kubectl_manifest" "crd" {
  for_each = toset(local.crd_files)

  yaml_body         = file("${local.dir}/${each.value}")
  server_side_apply = true
  force_conflicts   = true
  wait              = true
}
