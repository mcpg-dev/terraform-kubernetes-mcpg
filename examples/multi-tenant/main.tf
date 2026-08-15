# Example: multi-tenant fleet — operator + cluster trust, then a tenant
# (namespace + RBAC + NetworkPolicy + plugin-set + gateway) per entry in the
# `tenants` map. Add/remove a tenant = one map edit.
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

# A variable default cannot reference another variable, so every artefact ref
# composes off var.oci_registry_base here instead of repeating the base.
locals {
  gateway_image_repository = coalesce(var.gateway_image_repository, "${var.oci_registry_base}/gateway")
}

module "crds" {
  source   = "../../modules/crds"
  crds_dir = "${path.module}/../../../codegen/schemas/v1alpha1/crds"
}

module "operator" {
  source            = "../../modules/operator"
  namespace         = var.operator_namespace
  chart_version     = var.operator_chart_version
  oci_registry_base = var.oci_registry_base

  depends_on = [module.crds]
}

module "trust" {
  source      = "../../modules/trust-bootstrap"
  revocations = []

  depends_on = [module.operator]
}

module "tenant" {
  source   = "../../modules/tenant"
  for_each = var.tenants

  name           = each.key
  labels         = { "mcpg.dev/environment" = each.value.environment }
  network_policy = true

  gateway = {
    image      = { repository = local.gateway_image_repository, tag = var.gateway_image_tag }
    replicas   = each.value.replicas
    governance = { audit = { sinks = [{ kind = "dev.mcpg.builtin.audit.local-file" }] } }
  }
  plugin_set = {
    entries = each.value.plugins
  }

  depends_on = [module.operator, module.trust]
}
