variable "kubeconfig" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to the kubeconfig used by all three providers."
}

variable "namespace" {
  type        = string
  default     = "mcpg-system"
  description = "Namespace for the operator and the gateway."
}

variable "operator_chart_version" {
  type        = string
  default     = "0.1.0"
  description = "Pinned operator chart version."
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
  type        = string
  default     = "v1.0.0-rc.17"
  description = "Gateway image tag."
}
