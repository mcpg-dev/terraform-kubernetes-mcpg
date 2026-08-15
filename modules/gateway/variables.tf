variable "name" {
  type        = string
  description = "MCPGGateway name."
}

variable "namespace" {
  type        = string
  description = "Namespace to create the gateway in."
}

variable "image" {
  type        = any
  description = "Gateway image (CRD spec.image — e.g. { repository, tag, pullPolicy }). Required by the CRD."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the MCPGGateway metadata."
}

# ── config builder (typed sections; null = omitted) ──────────────────────
variable "server" {
  type        = any
  default     = null
  description = "Gateway server/listener config. Emitted at config.gateway.server (the `gateway:` AppConfig umbrella), NOT a top-level `server` key."
}

variable "governance" {
  type        = any
  default     = null
  description = <<-EOT
    config.governance section (access / policy / approvals / audit). Audit sinks
    use a list, not a scalar: { audit = { sinks = [{ kind = "dev.mcpg.builtin.audit.local-file" }] } }.
    `dev.mcpg.builtin.audit.local-file` is the canonical built-in audit sink
    (the `stderr`/`file` keywords are observability sink kinds, not audit kinds).
  EOT
}

variable "observability" {
  type        = any
  default     = null
  description = "config.observability section."
}

variable "mcp" {
  type        = any
  default     = null
  description = "config.mcp section (capabilities, etc.)."
}

variable "plugins" {
  type        = list(any)
  default     = []
  description = <<-EOT
    Ordered config.plugins list (AppConfig PluginEntryConfig). Each entry:
    { id, source = { path | oci }, class? (default "tool_gate"), kind? (default
    "native"), config?, enforce?, granted_capabilities?, disabled? }. NOTE: the
    toggle is `disabled` (bool, default false) — there is no `enabled` field. A
    `source` declaring exactly one of path/oci is REQUIRED or the gateway
    rejects the entry at boot.
  EOT
}

variable "extra_config" {
  type        = any
  default     = {}
  description = "Arbitrary AppConfig fragment deep-merged LAST into spec.config (escape hatch). Wins over typed sections."
}

# ── K8s wrapper blocks (CRD spec.* — null = omitted) ─────────────────────
variable "replicas" {
  type    = number
  default = null
}
variable "plugin_set_ref" {
  type    = string
  default = null
}
variable "revocation_list_ref" {
  type    = string
  default = null
}
variable "cluster_ref" {
  type        = string
  default     = null
  description = "Name of an MCPGCluster coordination backend (spec.clusterRef). The MCPGCluster (and any backend credential Secrets it needs in the operator namespace) must exist — provision both with `modules/cluster`, otherwise the gateway binds to a coordinator with unresolved cred://cluster/* references."
}
variable "resources" {
  type    = any
  default = null
}
variable "service" {
  type    = any
  default = null
}
variable "ingress" {
  type    = any
  default = null
}
variable "autoscaling" {
  type    = any
  default = null
}
variable "monitoring" {
  type    = any
  default = null
}
variable "network_policy" {
  type    = any
  default = null
}
variable "pod_disruption_budget" {
  type    = any
  default = null
}
variable "workload_identity" {
  type    = any
  default = null
}
variable "scheduling" {
  type    = any
  default = null
}
variable "probes" {
  type    = any
  default = null
}
variable "image_pull_secrets" {
  type    = any
  default = null
}
variable "accepted_route_namespaces" {
  type        = list(string)
  default     = null
  description = "Soft-tenancy: namespaces whose MCPGRoutes this gateway accepts (spec.acceptedRouteNamespaces). A route in an unlisted namespace is admission-rejected; leave null to accept the gateway's own namespace only."
}
variable "pod_annotations" {
  type    = map(string)
  default = null
}
variable "pod_labels" {
  type    = map(string)
  default = null
}

variable "extra_spec" {
  type        = any
  default     = {}
  description = "Arbitrary spec-level fields merged last (for spec keys not yet typed as variables)."
}

variable "wait" {
  type        = bool
  default     = true
  description = "Wait for the MCPGGateway CR to be applied/accepted. NOTE: this does NOT block on the operator's Ready condition — wait-on-Ready is the native provider's job."
}
