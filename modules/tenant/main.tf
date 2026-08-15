# modules/tenant — one MCPG tenant as an IMPERATIVE fan-out: namespace + RBAC +
# NetworkPolicy + (optional) MCPGPluginSet + MCPGGateway. Call with `for_each`
# over a tenant map to fan out a fleet. Per-namespace isolation is
# on by default.
#
# NB: this does NOT create an `MCPGTenant` CR, so it does NOT engage the
# operator's tenant GOVERNANCE (plugin allowlist, ResourceQuota, replica caps,
# exclusive namespace ownership). For declarative governance use
# `modules/tenant-cr` (the MCPGTenant CR) — alongside or instead of this helper.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.30" }
    kubectl    = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

variable "name" { type = string }
variable "namespace" {
  type        = string
  default     = null
  description = "Namespace (defaults to the tenant name)."
}
variable "labels" {
  type    = map(string)
  default = {}
}
variable "tenant_cluster_role" {
  type        = string
  default     = "mcpg-tenant"
  description = "ClusterRole bound into the tenant namespace. The operator chart ships `mcpg-tenant` (tenant-admin over the namespaced user-facing CRDs) when `rbac.tenantRole=true` (the default)."
}
variable "rbac_subjects" {
  type        = list(any)
  default     = []
  description = "Subjects (kind/name/namespace) bound to the tenant ClusterRole."
}
variable "network_policy" {
  type    = bool
  default = true
}
variable "gateway_mcp_port" {
  type        = number
  default     = 8787
  description = "Gateway MCP service port the isolation NetworkPolicy keeps reachable (so clients outside the tenant namespace can still reach the gateway)."
}
variable "plugin_set" {
  type        = any
  default     = null
  description = "Optional plugin-set ({ name?, entries, capability_grants? })."
}
variable "gateway" {
  type        = any
  default     = null
  description = "Optional gateway ({ name?, image, replicas?, governance?, plugins?, extra_config? })."
}

locals {
  ns = coalesce(var.namespace, var.name)
}

resource "kubernetes_namespace" "tenant" {
  metadata {
    name = local.ns
    labels = merge({
      "app.kubernetes.io/managed-by" = "terraform-mcpg"
      "mcpg.dev/tenant"              = var.name
    }, var.labels)
  }
}

resource "kubernetes_role_binding" "tenant" {
  count = length(var.rbac_subjects) > 0 ? 1 : 0
  metadata {
    name      = "mcpg-tenant"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = var.tenant_cluster_role
  }
  dynamic "subject" {
    for_each = var.rbac_subjects
    content {
      kind      = subject.value.kind
      name      = subject.value.name
      namespace = try(subject.value.namespace, null)
      api_group = try(subject.value.api_group, "")
    }
  }
}

# Default-deny cross-tenant ingress; allow within the tenant's own namespaces.
# NB: this selects ALL pods (pod_selector {}), including the operator-deployed
# gateway. The gateway serves MCP on `gateway_mcp_port` to clients that live
# OUTSIDE the tenant namespace (ingress controllers, other apps), so a pure
# tenant-only ingress would make the gateway unreachable. The second rule keeps
# the MCP port open (any source) while general cross-tenant pod traffic stays
# denied; tighten the gateway exposure with your own policy / ingress controller.
resource "kubernetes_network_policy" "tenant_isolation" {
  count = var.network_policy ? 1 : 0
  metadata {
    name      = "mcpg-tenant-isolation"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    # Intra-tenant: pods reachable from the tenant's own namespaces.
    ingress {
      from {
        namespace_selector {
          match_labels = { "mcpg.dev/tenant" = var.name }
        }
      }
    }
    # Keep the gateway's MCP port reachable by external clients (a rule with
    # `ports` and no `from` allows that port from any source).
    ingress {
      ports {
        port     = tostring(var.gateway_mcp_port)
        protocol = "TCP"
      }
    }
  }
}

module "plugin_set" {
  count             = var.plugin_set == null ? 0 : 1
  source            = "../plugin-set"
  name              = try(var.plugin_set.name, "${var.name}-set")
  namespace         = kubernetes_namespace.tenant.metadata[0].name
  entries           = try(var.plugin_set.entries, [])
  capability_grants = try(var.plugin_set.capability_grants, [])
}

module "gateway" {
  count          = var.gateway == null ? 0 : 1
  source         = "../gateway"
  name           = try(var.gateway.name, var.name)
  namespace      = kubernetes_namespace.tenant.metadata[0].name
  image          = try(var.gateway.image, null)
  replicas       = try(var.gateway.replicas, null)
  governance     = try(var.gateway.governance, null)
  plugins        = try(var.gateway.plugins, [])
  plugin_set_ref = var.plugin_set == null ? null : module.plugin_set[0].name
  extra_config   = try(var.gateway.extra_config, {})
}

output "namespace" { value = kubernetes_namespace.tenant.metadata[0].name }
output "gateway_name" { value = try(module.gateway[0].name, null) }
output "plugin_set_name" { value = try(module.plugin_set[0].name, null) }
