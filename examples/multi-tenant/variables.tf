variable "kubeconfig" {
  type    = string
  default = "~/.kube/config"
}

variable "operator_namespace" {
  type    = string
  default = "mcpg-system"
}

variable "operator_chart_version" {
  type    = string
  default = "0.1.0"
}

variable "oci_registry_base" {
  type        = string
  default     = "ghcr.io/mcpg-dev/source-code"
  description = "Registry base every MCPG artefact hangs off (charts at <base>/charts, images at <base>/<name>). Mirrors tools/release/oci-registry.json."
}

variable "gateway_image_repository" {
  type        = string
  default     = null
  description = "Gateway image repository. Null composes <oci_registry_base>/gateway."
}

variable "gateway_image_tag" {
  type    = string
  default = "v1.0.0-rc.17"
}

variable "tenants" {
  description = "Tenant map — one gateway fleet per entry."
  type = map(object({
    environment = string
    replicas    = optional(number, 1)
    plugins     = optional(list(any), [])
  }))
  default = {
    team-a = { environment = "prod", replicas = 2 }
    team-b = { environment = "staging" }
    team-c = { environment = "dev" }
  }
}
