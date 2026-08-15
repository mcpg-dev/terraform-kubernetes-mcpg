# Example: governance coverage — the CRDs the module suite previously couldn't
# manage. Stands up a coordination backend (MCPGCluster), a shared gateway bound
# to it, a declarative tenant boundary (MCPGTenant), and a tenant-scoped route
# into the shared gateway (MCPGRoute). Demonstrates the shared-gateway-per-tenant
# model end to end.
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

module "crds" {
  source   = "../../modules/crds"
  crds_dir = "${path.module}/../../../codegen/schemas/v1alpha1/crds"
}

module "operator" {
  source            = "../../modules/operator"
  namespace         = var.namespace
  chart_version     = var.operator_chart_version
  oci_registry_base = var.oci_registry_base

  depends_on = [module.crds]
}

# Coordination backend (HA clustering) the shared gateway binds to. The Redis
# password Secret is created in the operator namespace and surfaced to the
# gateway as cred://cluster/password (the credential plane is fully IaC-managed).
module "cluster" {
  source             = "../../modules/cluster"
  name               = "prod"
  operator_namespace = var.namespace
  backend            = "redis"
  config             = { url = "redis://redis.mcpg-system.svc:6379" }
  credentials = [{
    name        = "password"
    secret_name = "redis-password"
    data        = { password = "change-me-in-prod" }
  }]

  depends_on = [module.operator]
}

# Declarative tenant governance for the team-a namespace.
module "tenant" {
  source          = "../../modules/tenant-cr"
  name            = "team-a"
  namespaces      = ["team-a"]
  allowed_plugins = [{ name = "dev.mcpg.policy.cedar" }]
  quotas          = { maxGateways = 2, maxReplicasPerGateway = 3 }

  depends_on = [module.operator]
}

# Shared gateway, HA via the cluster backend.
module "gateway" {
  source    = "../../modules/gateway"
  name      = "shared"
  namespace = var.namespace

  image = {
    repository = local.gateway_image_repository
    tag        = var.gateway_image_tag
  }
  cluster_ref = module.cluster.name

  depends_on = [module.operator]
}

# Tenant-scoped route: team-a's tools into the shared gateway.
module "route" {
  source      = "../../modules/route"
  name        = "team-a-route"
  namespace   = var.namespace
  gateway_ref = { name = module.gateway.name }
  match       = { tools = [{ id = "db.read" }] }
  attributes  = { tenant = "team-a" }

  depends_on = [module.gateway]
}
