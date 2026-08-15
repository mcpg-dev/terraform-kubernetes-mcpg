variable "release_name" {
  type        = string
  default     = "mcpg-operator"
  description = "Helm release name."
}

variable "namespace" {
  type        = string
  default     = "mcpg-system"
  description = "Namespace the operator is installed into."
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Create the namespace if it does not exist."
}

variable "oci_registry_base" {
  type        = string
  default     = "ghcr.io/mcpg-dev/source-code"
  description = "Registry base (<host>/<namespace>[/<path>]) every MCPG artefact hangs off. Charts live at <base>/charts, images at <base>/<name>, plugins at <base>/plugins. Mirrors tools/release/oci-registry.json — tools/ci/selftest-oci-registry.sh asserts they agree."
}

variable "chart_repository" {
  type        = string
  default     = null
  description = "Helm chart repository (HTTPS or oci://). Null composes oci://<oci_registry_base>/charts; set it to point at a repository that does not follow that layout."
}

variable "chart_name" {
  type        = string
  default     = "mcpg-operator"
  description = "Helm chart name."
}

variable "chart_version" {
  type        = string
  description = "Pinned operator chart version (required — never float)."
}

variable "sizing_preset" {
  type        = string
  default     = "medium"
  description = "small | medium | large — maps to the chart's values{,-medium,-large}.yaml."

  validation {
    condition     = contains(["small", "medium", "large"], var.sizing_preset)
    error_message = "sizing_preset must be one of: small, medium, large."
  }
}

variable "webhook" {
  type        = any
  default     = null
  description = "Webhook TLS config passed under chart `webhook` (cert-manager issuerRef or pre-provisioned Secret). Null = chart default."
}

variable "watch_namespace" {
  type        = string
  default     = null
  description = "Restrict the operator to a single namespace (chart operator.watchNamespace → --watch-namespace). Null = watch all namespaces. Use for per-namespace / multi-scoped-operator topologies."
}

variable "values" {
  type        = any
  default     = {}
  description = "Extra chart values deep-merged last (escape hatch)."
}

variable "atomic" {
  type        = bool
  default     = false
  description = "Roll back the release on a failed install/upgrade."
}

variable "timeout_seconds" {
  type        = number
  default     = 600
  description = "Helm wait timeout."
}

variable "cert_manager" {
  type        = any
  default     = null
  description = <<-EOT
    cert-manager webhook TLS, passed to the chart's `certManager` values. The
    chart templates a self-signed Issuer + Certificate and injects the webhook
    caBundle. Example:
    { enabled = true, issuerRef = { name = "mcpg-operator-selfsigned", kind = "Issuer", group = "cert-manager.io" } }

    Default behaviour when null: cert-manager is enabled automatically UNLESS
    `webhook` (bring-your-own Secret) is set. This is the secure default — the
    admission webhook fails closed, so it must have real TLS or every CR apply
    hangs. REQUIRES cert-manager to be installed in the cluster; to opt out,
    pass `{ enabled = false }` here together with a `webhook` Secret config.
  EOT
}
