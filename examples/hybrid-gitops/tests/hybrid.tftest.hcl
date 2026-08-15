# Offline test: TF bootstraps layers 0–2 and emits the GitOps handoff. No
# gateways are created here (those are GitOps-owned), so there is nothing for
# the operator to fight over — the no-drift-loop property.

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "kubectl" {}

variables {
  kubeconfig             = "/dev/null"
  operator_chart_version = "0.1.0"
}

run "emits_handoff_for_gitops" {
  command = plan

  assert {
    condition     = output.operator_namespace == "mcpg-system"
    error_message = "operator namespace handoff missing"
  }

  assert {
    condition     = length(output.tenant_namespaces) == 2
    error_message = "expected two tenant namespaces as the GitOps boundary"
  }

  assert {
    condition     = contains(output.tenant_namespaces, "team-a")
    error_message = "tenant namespace team-a not created"
  }

  assert {
    condition     = output.cluster_default_revocation_list == "cluster-default"
    error_message = "cluster-default revocation list handoff missing"
  }
}
