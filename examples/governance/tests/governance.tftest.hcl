# Offline test: the four previously-unmanageable CRDs render with the right
# shapes and wire together (cluster <- gateway.clusterRef; tenant boundary;
# tenant-scoped route into the shared gateway).

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "kubectl" {}

variables {
  kubeconfig             = "/dev/null"
  operator_chart_version = "0.1.0"
}

run "governance_crds_render_and_wire" {
  command = plan

  # MCPGCluster: external backend carries a connection config.
  assert {
    condition     = output.cluster_manifest.kind == "MCPGCluster" && output.cluster_manifest.spec.backend == "redis"
    error_message = "cluster should render an MCPGCluster with the redis backend"
  }
  assert {
    condition     = output.cluster_manifest.spec.config.url != ""
    error_message = "external cluster backend must carry a connection config"
  }
  # The credential plane is IaC-managed: the credentialRef is wired to a
  # Secret this module creates in the operator namespace (extra-5).
  assert {
    condition     = output.cluster_manifest.spec.credentialRefs[0].name == "password" && output.cluster_manifest.spec.credentialRefs[0].secretName == "redis-password"
    error_message = "cluster credential plane (cred://cluster/password) not wired"
  }

  # MCPGTenant: governance boundary with allowlist + quotas.
  assert {
    condition     = output.tenant_manifest.kind == "MCPGTenant" && output.tenant_manifest.spec.namespaces[0] == "team-a"
    error_message = "tenant should own the team-a namespace"
  }
  assert {
    condition     = output.tenant_manifest.spec.allowedPlugins[0].name == "dev.mcpg.policy.cedar"
    error_message = "tenant plugin allowlist not wired"
  }

  # Gateway is bound to the cluster backend.
  assert {
    condition     = output.gateway_manifest.spec.clusterRef.name == "prod"
    error_message = "shared gateway must reference the cluster backend"
  }

  # MCPGRoute: tenant-scoped tools into the shared gateway.
  assert {
    condition     = output.route_manifest.kind == "MCPGRoute" && output.route_manifest.spec.gatewayRef.name == "shared"
    error_message = "route must bind into the shared gateway"
  }
  assert {
    condition     = output.route_manifest.spec.attributes.tenant == "team-a"
    error_message = "route must be tenant-scoped (else reachable by any caller)"
  }
}
