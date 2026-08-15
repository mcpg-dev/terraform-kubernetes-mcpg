# modules/plugin-set — render and apply an MCPGPluginSet (namespaced).
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

variable "name" { type = string }
variable "namespace" { type = string }
variable "entries" {
  type        = list(any)
  description = "Plugin-set entries (id, pluginRef, enabled, enforce, config)."
}
variable "capability_grants" {
  type        = any
  default     = {}
  description = "Capability grants: a MAP keyed by entry id → non-empty list of capabilities (matches the CRD's capabilityGrants object), e.g. { \"dev.mcpg.policy.cedar\" = [\"network_outbound\"] }. NOT a list."
}
variable "labels" {
  type    = map(string)
  default = {}
}

locals {
  manifest = {
    apiVersion = "mcpg.dev/v1alpha1"
    kind       = "MCPGPluginSet"
    metadata   = { name = var.name, namespace = var.namespace, labels = var.labels }
    spec = merge(
      { entries = var.entries },
      length(var.capability_grants) > 0 ? { capabilityGrants = var.capability_grants } : {},
    )
  }
}

resource "kubectl_manifest" "plugin_set" {
  yaml_body         = yamlencode(local.manifest)
  server_side_apply = true
  force_conflicts   = true
}

output "name" { value = var.name }
output "namespace" { value = var.namespace }
output "manifest" { value = local.manifest }
