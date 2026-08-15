variable "crds_dir" {
  type        = string
  default     = null
  description = "Directory of split-by-kind CRD YAMLs. Defaults to the in-repo schema snapshot."
}

variable "namespace" {
  type        = string
  default     = "mcpg-system"
  description = "Namespace for the operator + gateway."
}

variable "operator_chart_version" {
  type        = string
  description = "Pinned operator chart version (required)."
}

variable "oci_registry_base" {
  type        = string
  default     = "ghcr.io/mcpg-dev/source-code"
  description = "Registry base (<host>/<namespace>[/<path>]) every MCPG artefact hangs off. Charts live at <base>/charts, images at <base>/<name>, plugins at <base>/plugins. Mirrors tools/release/oci-registry.json — tools/ci/selftest-oci-registry.sh asserts they agree."
}

variable "sizing_preset" {
  type        = string
  default     = "medium"
  description = "small | medium | large."
}

variable "cert_manager" {
  type        = any
  default     = null
  description = <<-EOT
    cert-manager webhook TLS config (chart `certManager` values). When null
    (default) and `webhook` is unset, cert-manager is enabled automatically —
    the secure default for the fail-closed admission webhook. REQUIRES
    cert-manager installed in the cluster. Pass `{ enabled = false }` + a
    `webhook` Secret config to bring your own TLS.
  EOT
}

variable "webhook" {
  type        = any
  default     = null
  description = "Pre-provisioned webhook TLS config (chart `webhook` values). Setting this disables the cert-manager default (BYO TLS Secret)."
}

variable "watch_namespace" {
  type        = string
  default     = null
  description = "Restrict the operator to a single namespace (operator.watchNamespace). Null = watch all."
}

variable "operator_values" {
  type        = any
  default     = {}
  description = "Extra operator chart values, deep-merged last."
}

variable "bootstrap_trust" {
  type        = bool
  default     = true
  description = "Seed the cluster-default MCPGRevocationList."
}

variable "plugin_set" {
  type        = any
  default     = null
  description = "Optional plugin-set: { name?, entries, capability_grants? }."
}

variable "gateway" {
  type        = any
  default     = null
  description = "Optional gateway: { name, image, replicas?, governance?, plugins?, extra_config? }."
}
