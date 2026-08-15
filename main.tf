# Root module — the common case in one call: CRDs + operator + cluster-default
# trust + (optionally) one plugin-set + one gateway. Compose the
# submodules directly for anything more bespoke. Providers are configured by the
# caller (this is a reusable module).
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.30" }
    helm       = { source = "hashicorp/helm", version = ">= 2.13" }
    kubectl    = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

module "crds" {
  source   = "./modules/crds"
  crds_dir = var.crds_dir
}

module "operator" {
  source            = "./modules/operator"
  namespace         = var.namespace
  chart_version     = var.operator_chart_version
  oci_registry_base = var.oci_registry_base
  sizing_preset     = var.sizing_preset
  cert_manager      = var.cert_manager
  webhook           = var.webhook
  watch_namespace   = var.watch_namespace
  values            = var.operator_values

  depends_on = [module.crds]
}

module "trust" {
  count  = var.bootstrap_trust ? 1 : 0
  source = "./modules/trust-bootstrap"

  depends_on = [module.operator]
}

module "plugin_set" {
  count     = var.plugin_set == null ? 0 : 1
  source    = "./modules/plugin-set"
  name      = try(var.plugin_set.name, "${try(var.gateway.name, "mcpg")}-set")
  namespace = var.namespace

  entries           = try(var.plugin_set.entries, [])
  capability_grants = try(var.plugin_set.capability_grants, [])

  depends_on = [module.operator]
}

module "gateway" {
  count     = var.gateway == null ? 0 : 1
  source    = "./modules/gateway"
  name      = var.gateway.name
  namespace = var.namespace

  image          = var.gateway.image
  replicas       = try(var.gateway.replicas, null)
  governance     = try(var.gateway.governance, null)
  plugins        = try(var.gateway.plugins, [])
  plugin_set_ref = var.plugin_set == null ? null : module.plugin_set[0].name
  extra_config   = try(var.gateway.extra_config, {})

  depends_on = [module.operator]
}
