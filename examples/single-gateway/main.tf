# Example: single gateway — operator + CRDs + one MCPGGateway.
# `terraform apply` installs the operator, applies the CRDs, and creates a
# gateway that reaches Ready. Run against a cluster:
#   tofu init && tofu apply -var kubeconfig=~/.kube/config
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

# A variable default cannot reference another variable, so every artefact ref
# composes off var.oci_registry_base here instead of repeating the base.
locals {
  gateway_image_repository = coalesce(var.gateway_image_repository, "${var.oci_registry_base}/gateway")
}

# Layer 2 — CRDs applied independently of the operator chart.
module "crds" {
  source   = "../../modules/crds"
  crds_dir = "${path.module}/../../../codegen/schemas/v1alpha1/crds"
}

# Layer 1 — operator install. Ordered after the CRDs.
module "operator" {
  source            = "../../modules/operator"
  namespace         = var.namespace
  chart_version     = var.operator_chart_version
  oci_registry_base = var.oci_registry_base

  depends_on = [module.crds]
}

# Layer 3 — one gateway. Ordered after the operator is Ready.
module "gateway" {
  source    = "../../modules/gateway"
  name      = "orders"
  namespace = var.namespace

  image = {
    repository = local.gateway_image_repository
    tag        = var.gateway_image_tag
  }
  replicas = 2

  # Typed config section — the builder merges these into spec.config.
  # Audit fans out via a sinks LIST; dev.mcpg.builtin.audit.local-file is the
  # canonical built-in audit sink (a bare "stderr" is an observability sink
  # keyword, not a valid audit kind, and would fail to resolve at boot).
  governance = {
    audit = { sinks = [{ kind = "dev.mcpg.builtin.audit.local-file" }] }
  }

  depends_on = [module.operator]
}
