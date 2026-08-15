# modules/cluster — an MCPGCluster (cluster-scoped): the cluster-coordination
# backend binding the gateway's `clusterRef` points at. `single_node` (default)
# is the in-process coordinator and takes NO config; external backends
# (redis/nats/consul/etcd) require a non-empty `config` connection block.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl    = { source = "alekc/kubectl", version = ">= 2.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.30" }
  }
}

variable "name" { type = string }
variable "operator_namespace" {
  type        = string
  default     = "mcpg-system"
  description = "Namespace the operator runs in — where the backend credential Secrets (credentialRefs) MUST live to be projected into gateways."
}
variable "backend" {
  type        = string
  default     = "single_node"
  description = "Coordination backend: single_node | redis | nats | consul | etcd."
  validation {
    condition     = contains(["single_node", "redis", "nats", "consul", "etcd"], var.backend)
    error_message = "backend must be one of: single_node, redis, nats, consul, etcd."
  }
}
variable "config" {
  type        = any
  default     = {}
  description = "Per-backend connection config (url/servers/endpoints/...). MUST be empty for single_node, non-empty otherwise."
}
variable "plugin_ref" {
  type        = any
  default     = null
  description = "Optional { name } of the cluster-scoped MCPGPlugin supplying the dev.mcpg.cluster.<backend> cdylib (operator gates on it being Ready)."
}
variable "credential_refs" {
  type        = any
  default     = []
  description = "Optional [{ name, secretName, key? }] referencing PRE-EXISTING Secrets in the operator namespace, surfaced to gateways as cred://cluster/<name>. For Secrets this module should also CREATE, use `credentials` instead."
}
variable "credentials" {
  type = list(object({
    name        = string
    secret_name = string
    key         = optional(string)
    data        = optional(map(string))
  }))
  default     = []
  description = <<-EOT
    Backend credentials surfaced as cred://cluster/<name>. When `data` is set,
    this module CREATES the Secret in `operator_namespace` (so the credential
    plane is fully IaC-managed) and wires the credentialRef automatically; when
    `data` is null the named Secret is assumed to pre-exist. Each `name` maps to
    a distinct cred://cluster/<name> and must be unique.
  EOT
}
variable "labels" {
  type    = map(string)
  default = {}
}
variable "extra_spec" {
  type    = any
  default = {}
}

resource "kubernetes_secret" "cred" {
  for_each = { for c in var.credentials : c.name => c if c.data != null }
  metadata {
    name      = each.value.secret_name
    namespace = var.operator_namespace
    labels    = { "app.kubernetes.io/managed-by" = "terraform-mcpg" }
  }
  data = each.value.data
  type = "Opaque"
}

locals {
  # credentialRefs from the managed `credentials` (Secret created above OR
  # pre-existing), merged with any raw `credential_refs` passthrough.
  managed_credential_refs = [for c in var.credentials : merge(
    { name = c.name, secretName = c.secret_name },
    c.key == null ? {} : { key = c.key },
  )]
  all_credential_refs = concat(tolist(var.credential_refs), local.managed_credential_refs)

  manifest = {
    apiVersion = "mcpg.dev/v1alpha1"
    kind       = "MCPGCluster"
    metadata   = { name = var.name, labels = var.labels }
    spec = merge(
      { backend = var.backend },
      length(var.config) > 0 ? { config = var.config } : {},
      var.plugin_ref == null ? {} : { pluginRef = var.plugin_ref },
      length(local.all_credential_refs) > 0 ? { credentialRefs = local.all_credential_refs } : {},
      var.extra_spec,
    )
  }
}

resource "kubectl_manifest" "cluster" {
  yaml_body         = yamlencode(local.manifest)
  server_side_apply = true
  force_conflicts   = true
  # Ensure the backend credential Secrets exist before the operator reconciles.
  depends_on = [kubernetes_secret.cred]
}

output "name" { value = var.name }
output "manifest" { value = local.manifest }
