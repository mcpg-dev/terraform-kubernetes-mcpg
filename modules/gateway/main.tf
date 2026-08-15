# modules/gateway — render and apply an MCPGGateway (layer 3).
#
# Wraps the namespaced MCPGGateway CRD. The `config` builder assembles the
# gateway's AppConfig (spec.config is x-kubernetes-preserve-unknown-fields)
# from typed sections plus an `extra_config` escape hatch merged LAST, so no
# config field is unreachable. Spec validation is performed
# by the gateway at boot in Phase 1; the native provider adds plan-time
# validation in Phase 2.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

locals {
  # ── config builder ────────────────────────────────────────────────────
  # Typed convenience sections; null sections are omitted. extra_config is
  # deep-merged last and wins, so any not-yet-typed surface is reachable.
  # NB: `server` lives at config.gateway.server in AppConfig (the `gateway:`
  # umbrella holds server/admin/control_plane), NOT at the top level. Emitting
  # a top-level `server` key trips AppConfig's deny_unknown_fields at boot.
  # governance / observability / mcp / plugins ARE top-level keys.
  typed_sections = {
    gateway       = var.server == null ? null : { server = var.server }
    governance    = var.governance
    observability = var.observability
    mcp           = var.mcp
    plugins       = length(var.plugins) > 0 ? var.plugins : null
  }

  built_config = merge(
    { for k, v in local.typed_sections : k => v if v != null },
    var.extra_config,
  )

  # ── spec assembly ─────────────────────────────────────────────────────
  # image + config are required by the CRD; everything else is emitted only
  # when set, so we never write empty optional blocks.
  spec = merge(
    {
      image  = var.image
      config = local.built_config
    },
    var.replicas == null ? {} : { replicas = var.replicas },
    var.plugin_set_ref == null ? {} : { pluginSetRef = { name = var.plugin_set_ref } },
    var.revocation_list_ref == null ? {} : { revocationListRef = { name = var.revocation_list_ref } },
    var.cluster_ref == null ? {} : { clusterRef = { name = var.cluster_ref } },
    var.resources == null ? {} : { resources = var.resources },
    var.service == null ? {} : { service = var.service },
    var.ingress == null ? {} : { ingress = var.ingress },
    var.autoscaling == null ? {} : { autoscaling = var.autoscaling },
    var.monitoring == null ? {} : { monitoring = var.monitoring },
    var.network_policy == null ? {} : { networkPolicy = var.network_policy },
    var.pod_disruption_budget == null ? {} : { podDisruptionBudget = var.pod_disruption_budget },
    var.workload_identity == null ? {} : { workloadIdentity = var.workload_identity },
    var.scheduling == null ? {} : { scheduling = var.scheduling },
    var.probes == null ? {} : { probes = var.probes },
    var.image_pull_secrets == null ? {} : { imagePullSecrets = var.image_pull_secrets },
    var.accepted_route_namespaces == null ? {} : { acceptedRouteNamespaces = var.accepted_route_namespaces },
    var.pod_annotations == null ? {} : { podAnnotations = var.pod_annotations },
    var.pod_labels == null ? {} : { podLabels = var.pod_labels },
    var.extra_spec,
  )

  manifest = {
    apiVersion = "mcpg.dev/v1alpha1"
    kind       = "MCPGGateway"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels    = var.labels
    }
    spec = local.spec
  }
}

resource "kubectl_manifest" "gateway" {
  yaml_body         = yamlencode(local.manifest)
  server_side_apply = true
  force_conflicts   = true

  # `wait` here only confirms the MCPGGateway CR was applied/accepted — the
  # alekc/kubectl boolean `wait` (no `wait_for` block) does NOT block on the
  # operator's custom `Ready` condition. True wait-on-Ready (and failedEntries
  # reason surfacing) is the native provider's job (Phase 2); a `wait_for {
  # condition { type = "Ready" status = "True" } }` block could be added here if
  # plan-time blocking on operator readiness is wanted.
  wait = var.wait
}
