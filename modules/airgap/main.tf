# modules/airgap — air-gap profile. Stands up the in-cluster
# MCPGPluginMirror and surfaces (a) the mirror name for MCPGPlugin oci.mirrorRef
# and (b) the in-cluster mirror host for direct image pulls (gateway/operator
# images, which are NOT rewritten by mirrorRef). The operator's airgap-enforced +
# offline Sigstore trust-root settings ride the operator module's `values`.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

variable "mirror_name" {
  type    = string
  default = "cluster-mirror"
}
variable "mirror_service" {
  type = object({
    namespace   = string
    name        = string
    port        = number
    path_prefix = optional(string)
  })
  description = "In-cluster OCI mirror Service coordinates (MCPGPluginMirror.spec.endpoint.service)."
}
variable "mirror_insecure" {
  type        = bool
  default     = true
  description = "Treat the mirror as plain-HTTP / self-signed (the common in-cluster case)."
}
variable "upstream" {
  type = object({
    registry  = string
    namespace = string
  })
  description = "Public registry + namespace the mirror stands in for, e.g. { registry = \"ghcr.io\", namespace = \"mcpg-dev/source-code\" }."
}
variable "auth" {
  type    = any
  default = null
}
variable "labels" {
  type    = map(string)
  default = {}
}

locals {
  service_map = merge(
    {
      namespace = var.mirror_service.namespace
      name      = var.mirror_service.name
      port      = var.mirror_service.port
    },
    var.mirror_service.path_prefix == null ? {} : { pathPrefix = var.mirror_service.path_prefix },
  )
  endpoint = {
    service  = local.service_map
    insecure = var.mirror_insecure
  }
  # In-cluster registry host (matches MirrorService::host() in the operator).
  mirror_host = "${var.mirror_service.name}.${var.mirror_service.namespace}.svc.cluster.local:${var.mirror_service.port}"
}

module "mirror" {
  source   = "../plugin-mirror"
  name     = var.mirror_name
  endpoint = local.endpoint
  upstream = var.upstream
  auth     = var.auth
  labels   = var.labels
}

output "mirror_name" {
  value = module.mirror.name
}
output "mirror_host" {
  description = "In-cluster registry host (<name>.<ns>.svc.cluster.local:<port>) for direct image pulls."
  value       = local.mirror_host
}
output "upstream" {
  value = var.upstream
}
output "mirror_manifest" {
  description = "The rendered MCPGPluginMirror (for schema-shape assertions)."
  value       = module.mirror.manifest
}
