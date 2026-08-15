# Offline test for the root (common-case) module. Mock providers → plan-only.
# Verifies the composition wires up and that the sizing preset + cert-manager
# land in the operator chart values.

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "kubectl" {}

variables {
  operator_chart_version = "0.1.0"
  crds_dir               = "../codegen/schemas/v1alpha1/crds"
  gateway = {
    name  = "orders"
    image = { repository = "ghcr.io/mcpg-dev/source-code/gateway", tag = "v1.0.0-rc.17" }
  }
  plugin_set = { entries = [] }
}

run "composes_common_case" {
  command = plan

  assert {
    condition     = length(output.crd_kinds) == 9
    error_message = "root module should apply all 9 CRDs"
  }
  assert {
    condition     = output.operator_namespace == "mcpg-system"
    error_message = "operator namespace not wired"
  }
  assert {
    condition     = output.operator_values.crd.install == false
    error_message = "operator chart should have crd.install=false (CRDs owned by the crds module)"
  }
  assert {
    condition     = output.operator_values.replicaCount == 2
    error_message = "medium preset should set replicaCount=2"
  }
  assert {
    condition     = output.operator_values.certManager.enabled == true
    error_message = "cert-manager must default ON (secure default) when neither cert_manager nor webhook is set"
  }
  assert {
    condition     = output.gateway_name == "orders"
    error_message = "gateway not composed"
  }
  assert {
    condition     = output.plugin_set_name == "orders-set"
    error_message = "plugin-set not composed / named from the gateway"
  }
}

run "large_preset_and_cert_manager" {
  command = plan

  variables {
    sizing_preset = "large"
    cert_manager = {
      enabled   = true
      issuerRef = { name = "mcpg-operator-selfsigned", kind = "Issuer", group = "cert-manager.io" }
    }
  }

  assert {
    condition     = output.operator_values.replicaCount == 2
    error_message = "large preset should set replicaCount=2 (matching values-large.yaml)"
  }
  assert {
    condition     = output.operator_values.operator.resyncIntervalSecs == 1800
    error_message = "large preset should set the consumed operator.resyncIntervalSecs key"
  }
  assert {
    condition     = output.operator_values.certManager.enabled == true
    error_message = "cert_manager should flow into chart certManager values"
  }
}
