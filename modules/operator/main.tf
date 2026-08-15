# modules/operator — install the MCPG operator via Helm (layer 1).
#
# CRDs are deliberately NOT installed by the chart (`crd.install=false`);
# they are managed by the `crds` module so they upgrade independently.
# Order CRDs-before-operator at the call site with
# `depends_on = [module.crds]`.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    helm = { source = "hashicorp/helm", version = ">= 2.13" }
  }
}

locals {
  # A variable default cannot reference another variable, so the composed
  # default lives here and var.chart_repository stays the escape hatch for a
  # repository that does not follow the <base>/charts layout.
  chart_repository = coalesce(var.chart_repository, "oci://${var.oci_registry_base}/charts")

  # Sizing presets mirror the chart's values.yaml / values-medium.yaml /
  # values-large.yaml (replicaCount + resources + probe cadence + the operator
  # runtime keys the chart actually consumes). Callers select via
  # var.sizing_preset; var.values overrides any of it.
  preset_values = {
    small = {
      replicaCount = 1
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { cpu = 1, memory = "512Mi" }
      }
    }
    medium = {
      replicaCount = 2
      resources = {
        requests = { cpu = "200m", memory = "256Mi" }
        limits   = { cpu = 2, memory = "512Mi" }
      }
      livenessProbe  = { initialDelaySeconds = 10, periodSeconds = 15 }
      readinessProbe = { initialDelaySeconds = 5, periodSeconds = 5 }
      operator       = { resyncIntervalSecs = 600, reconcileConcurrency = 8 }
    }
    large = {
      replicaCount = 2
      resources = {
        requests = { cpu = "500m", memory = "512Mi" }
        limits   = { cpu = 4, memory = "1Gi" }
      }
      livenessProbe  = { initialDelaySeconds = 15, periodSeconds = 20 }
      readinessProbe = { initialDelaySeconds = 10, periodSeconds = 10 }
      operator       = { resyncIntervalSecs = 1800, reconcileConcurrency = 16 }
    }
  }
  preset = lookup(local.preset_values, var.sizing_preset, {})

  # operator.* runtime sub-block: preset tuning + optional watch_namespace,
  # deep-merged so the watch_namespace doesn't clobber the preset's runtime keys
  # (Terraform merge() at the top level is shallow).
  operator_block = merge(
    try(local.preset.operator, {}),
    var.watch_namespace == null ? {} : { watchNamespace = var.watch_namespace },
  )
  operator_values = length(local.operator_block) > 0 ? { operator = local.operator_block } : {}

  # CRDs are owned by the `crds` module — turn the chart's install off.
  base_values = {
    crd = { install = false }
  }

  # Webhook TLS — two modes, both chart-native:
  #   cert-manager: var.cert_manager = { enabled = true, issuerRef = {…} } — the
  #     chart templates a self-signed Issuer + Certificate and injects the
  #     webhook caBundle (cert-manager.io/inject-ca-from). REQUIRES cert-manager
  #     installed in the cluster.
  #   pre-provisioned: var.webhook carries the Secret-based config (BYO TLS).
  #
  # Secure-by-default: the webhook fails closed (failurePolicy=Fail), so a
  # missing/empty caBundle wedges every CR apply. When the caller specifies
  # NEITHER mode we default cert-manager ON — without this the chart mounts a
  # non-existent Secret and `wait=true` blocks to timeout. Bring-your-own-TLS
  # callers (var.webhook set) get cert-manager OFF; an explicit var.cert_manager
  # always wins (merged last). The merge keeps the result a single map type
  # regardless of which optional keys the caller supplies.
  webhook_values = var.webhook == null ? {} : { webhook = var.webhook }
  # 0-or-1 list (the canonical optional-value idiom — empty list unifies cleanly
  # where an empty object does not) spread into merge(), so the caller's
  # cert_manager (last-wins) overrides the secure default without a cross-type
  # conditional.
  cert_manager_overrides = var.cert_manager == null ? [] : [var.cert_manager]
  cert_manager_values = {
    certManager = merge(
      { enabled = var.webhook == null },
    local.cert_manager_overrides...)
  }

  values = merge(
    local.base_values,
    local.preset,
    local.operator_values,
    local.webhook_values,
    local.cert_manager_values,
    var.values,
  )
}

resource "helm_release" "operator" {
  name             = var.release_name
  namespace        = var.namespace
  create_namespace = var.create_namespace

  repository = local.chart_repository
  chart      = var.chart_name
  version    = var.chart_version

  # Block until the operator Deployment is Available + webhook serving, so
  # the `ready` output is a real readiness gate downstream CRs depend on.
  wait          = true
  wait_for_jobs = true
  atomic        = var.atomic
  timeout       = var.timeout_seconds

  values = [yamlencode(local.values)]
}
