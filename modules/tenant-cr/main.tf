# modules/tenant-cr — an MCPGTenant (cluster-scoped): the DECLARATIVE tenant
# governance boundary. The operator's tenant controller + admission
# guard enforce the plugin allowlist, per-namespace ResourceQuota, replica caps,
# and exclusive namespace ownership for the listed namespaces.
#
# NB: this is the governance CR — distinct from `modules/tenant`, which is an
# imperative namespace+RBAC+NetworkPolicy fan-out that does NOT engage tenant
# governance. Use this module (or both) when you want the allowlist/quota
# enforcement.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

variable "name" { type = string }
variable "namespaces" {
  type        = list(string)
  description = "Namespaces this tenant owns (non-empty, unique). A namespace with no owning tenant is unconstrained."
  validation {
    condition     = length(var.namespaces) > 0
    error_message = "namespaces must list at least one namespace."
  }
}
variable "allowed_plugins" {
  type        = any
  default     = []
  description = "Plugin allowlist: [{ name? , registryPrefix? }] — each entry must set at least one matcher. Empty list = deny-all (no plugins admitted for this tenant)."
}
variable "quotas" {
  type        = any
  default     = null
  description = "Optional quotas: { maxGateways?, maxPluginSets?, maxRoutes?, maxReplicasPerGateway? } — each ≥ 0."
}
variable "identity_attribute" {
  type        = any
  default     = null
  description = "Optional tenant identity binding: { key, ... } — key must be non-empty when set."
}
variable "labels" {
  type    = map(string)
  default = {}
}
variable "extra_spec" {
  type    = any
  default = {}
}

locals {
  manifest = {
    apiVersion = "mcpg.dev/v1alpha1"
    kind       = "MCPGTenant"
    metadata   = { name = var.name, labels = var.labels }
    spec = merge(
      { namespaces = var.namespaces },
      length(var.allowed_plugins) > 0 ? { allowedPlugins = var.allowed_plugins } : {},
      var.quotas == null ? {} : { quotas = var.quotas },
      var.identity_attribute == null ? {} : { identityAttribute = var.identity_attribute },
      var.extra_spec,
    )
  }
}

resource "kubectl_manifest" "tenant" {
  yaml_body         = yamlencode(local.manifest)
  server_side_apply = true
  force_conflicts   = true
}

output "name" { value = var.name }
output "manifest" { value = local.manifest }
