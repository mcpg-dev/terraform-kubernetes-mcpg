# modules/route — an MCPGRoute (namespaced): the soft-multi-tenancy primitive
# that binds a tenant's tool subset into a SHARED gateway with identity/policy/
# audit chains. Set `attributes.tenant` to scope the route — a route with no
# tenant is reachable by ANY caller the gateway admits (the operator admits it
# with a warning).
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

variable "name" { type = string }
variable "namespace" { type = string }
variable "gateway_ref" {
  type        = any
  description = "Shared gateway this route binds into: { name }. name must be non-empty."
}
variable "match" {
  type        = any
  description = "Tool matcher: { tools = [{ id }, ...] } — must list at least one unique, non-empty tool id."
}
variable "identity_chain" {
  type    = list(string)
  default = []
}
variable "policy_chain" {
  type    = list(string)
  default = []
}
variable "audit_chain" {
  type    = list(string)
  default = []
}
variable "attributes" {
  type        = any
  default     = null
  description = "Route attributes, e.g. { tenant = \"team-a\" }. Omit only for a single-tenant gateway."
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
    kind       = "MCPGRoute"
    metadata   = { name = var.name, namespace = var.namespace, labels = var.labels }
    spec = merge(
      {
        gatewayRef = var.gateway_ref
        match      = var.match
      },
      length(var.identity_chain) > 0 ? { identityChain = var.identity_chain } : {},
      length(var.policy_chain) > 0 ? { policyChain = var.policy_chain } : {},
      length(var.audit_chain) > 0 ? { auditChain = var.audit_chain } : {},
      var.attributes == null ? {} : { attributes = var.attributes },
      var.extra_spec,
    )
  }
}

resource "kubectl_manifest" "route" {
  yaml_body         = yamlencode(local.manifest)
  server_side_apply = true
  force_conflicts   = true
}

output "name" { value = var.name }
output "manifest" { value = local.manifest }
