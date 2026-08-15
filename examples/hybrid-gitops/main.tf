# Example: hybrid TF + GitOps. Terraform owns layers 0–2 (CRDs,
# operator, cluster-scoped trust, tenant namespaces); a GitOps controller
# (Argo CD / Flux) owns layer-3 CRs (MCPGGateway / MCPGPluginSet), referencing
# the handoff outputs below. No gateways are created here — that prevents a
# drift loop between Terraform and the operator/GitOps.
#
# Argo CD ApplicationSet consuming the handoff (illustrative):
#
#   apiVersion: argoproj.io/v1alpha1
#   kind: ApplicationSet
#   spec:
#     generators:
#       - list:
#           elements:    # ← from output.tenant_namespaces
#             - { ns: team-a }
#             - { ns: team-b }
#     template:
#       spec:
#         destination: { namespace: '{{ns}}' }
#         source: { repoURL: <git>, path: 'gateways/{{ns}}' }
#         # ignoreDifferences for group mcpg.dev /status (operator-owned)
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    helm       = { source = "hashicorp/helm", version = "~> 2.13" }
    kubectl    = { source = "alekc/kubectl", version = "~> 2.0" }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}
provider "kubectl" {
  config_path      = var.kubeconfig
  load_config_file = true
}

module "crds" {
  source   = "../../modules/crds"
  crds_dir = "${path.module}/../../../codegen/schemas/v1alpha1/crds"
}

module "operator" {
  source        = "../../modules/operator"
  namespace     = var.namespace
  chart_version = var.operator_chart_version

  depends_on = [module.crds]
}

module "trust" {
  source = "../../modules/trust-bootstrap"

  depends_on = [module.operator]
}

# TF owns the tenancy boundaries; Git owns the CRs inside them.
resource "kubernetes_namespace" "tenant" {
  for_each = toset(var.tenant_namespaces)

  metadata {
    name = each.value
    labels = {
      "mcpg.dev/tenant"              = each.value
      "app.kubernetes.io/managed-by" = "terraform-mcpg"
    }
  }

  depends_on = [module.operator]
}
