variable "kubeconfig" {
  type    = string
  default = "~/.kube/config"
}
variable "namespace" {
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
