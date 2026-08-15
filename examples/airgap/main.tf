# Example: air-gap — operator + in-cluster OCI mirror + a digest-pinned plugin
# pulled from the mirror, with no public-registry references.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    helm       = { source = "hashicorp/helm", version = "~> 2.13" }
    kubectl    = { source = "alekc/kubectl", version = "~> 2.0" }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}
provider "kubectl" {
  config_path      = var.kubeconfig
  load_config_file = true
}

# A variable default cannot reference another variable, so the upstream the
# mirror fronts composes off var.oci_registry_base here. The split is at the
# HOST segment: MCPGPluginMirror.spec.upstream is { registry, namespace }, and
# the rewrite only matches refs starting <registry>/<namespace>/.
locals {
  oci_base_segments = split("/", var.oci_registry_base)
  upstream = var.upstream != null ? var.upstream : {
    registry  = local.oci_base_segments[0]
    namespace = join("/", slice(local.oci_base_segments, 1, length(local.oci_base_segments)))
  }
}

module "crds" {
  source   = "../../modules/crds"
  crds_dir = "${path.module}/../../../codegen/schemas/v1alpha1/crds"
}

module "operator" {
  source            = "../../modules/operator"
  namespace         = var.namespace
  chart_version     = var.operator_chart_version
  oci_registry_base = var.oci_registry_base

  # Air-gap: image from the mirror + offline Sigstore trust root. Exact value
  # keys are chart-owned, so they ride the `values` escape hatch.
  values = var.operator_airgap_values

  depends_on = [module.crds]
}

# In-cluster OCI mirror (MCPGPluginMirror) — structured endpoint + upstream.
module "airgap" {
  source         = "../../modules/airgap"
  mirror_service = var.mirror_service
  upstream       = local.upstream

  depends_on = [module.operator]
}

# A plugin pinned by digest. NOTE: oci.image is the UPSTREAM public ref — the
# operator rewrites it onto the mirror via `mirrorRef` (rewrite only matches
# when the image starts with <upstream.registry>/<upstream.namespace>/, then
# fails closed). Pointing the image straight at the mirror would short-circuit
# the rewrite (`NotApplicable`) and the plugin would never reconcile.
module "plugin_sql" {
  source         = "../../modules/plugin"
  name           = "sql"
  plugin_id      = "dev.mcpg.backend.sql"
  plugin_class   = "backend"
  plugin_version = "1.4.2"

  oci = {
    image     = "${local.upstream.registry}/${local.upstream.namespace}/plugins/sql@${var.sql_plugin_digest}"
    mirrorRef = { name = module.airgap.mirror_name }
  }
  # signingKeyRef is the MANDATORY trust baseline (Ed25519); cosign/SLSA are
  # additive, not substitutes.
  trust = {
    signingKeyRef = { secretName = var.signing_key_secret }
    cosignIdentity = {
      certificateIdentityRegexp = "^https://github.com/mcpg-dev/.+$"
      oidcIssuer                = "https://token.actions.githubusercontent.com"
    }
  }

  depends_on = [module.airgap]
}

module "gateway" {
  source    = "../../modules/gateway"
  name      = "edge"
  namespace = var.namespace

  # The gateway container image is pulled directly by kubelet (NOT rewritten by
  # mirrorRef), so it must already point at a mirror-reachable ref.
  image = {
    repository = "${module.airgap.mirror_host}/${local.upstream.namespace}/gateway"
    tag        = var.gateway_image_tag
  }

  depends_on = [module.operator]
}
