# modules/plugin-mirror — an in-cluster OCI mirror (MCPGPluginMirror, cluster).
# The air-gap primitive: rehomes upstream plugin refs onto an in-cluster
# registry with a fail-closed pull rewrite (see operator air-gap support).
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

variable "name" { type = string }
variable "endpoint" {
  type        = any
  description = <<-EOT
    MCPGPluginMirror.spec.endpoint — the in-cluster registry Service. Object:
    { service = { namespace, name, port (1..65535), pathPrefix? }, insecure? }.
    `insecure = true` for plain-HTTP / self-signed in-cluster mirrors (the common
    case). NOTE: this is a structured object, NOT a host:port string.
  EOT
}
variable "upstream" {
  type        = any
  description = <<-EOT
    MCPGPluginMirror.spec.upstream — the public registry + namespace this mirror
    stands in for: { registry, namespace } (e.g. { registry = "ghcr.io",
    namespace = "mcpg-dev/source-code" }). Only plugin refs whose image starts
    with `<registry>/<namespace>/` are rewritten onto this mirror.
  EOT
}
variable "auth" {
  type        = any
  default     = null
  description = "Optional pull credentials: { secretRef = { secretName, key? } } — a dockerconfigjson Secret in the operator namespace."
}
variable "resync_interval" {
  type    = string
  default = null
}
variable "labels" {
  type    = map(string)
  default = {}
}

locals {
  manifest = {
    apiVersion = "mcpg.dev/v1alpha1"
    kind       = "MCPGPluginMirror"
    metadata   = { name = var.name, labels = var.labels }
    spec = merge(
      { endpoint = var.endpoint, upstream = var.upstream },
      var.auth == null ? {} : { auth = var.auth },
      var.resync_interval == null ? {} : { resyncInterval = var.resync_interval },
    )
  }
}

resource "kubectl_manifest" "mirror" {
  yaml_body         = yamlencode(local.manifest)
  server_side_apply = true
  force_conflicts   = true
}

output "name" { value = var.name }
output "endpoint" { value = var.endpoint }
output "manifest" { value = local.manifest }
