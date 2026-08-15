# Offline unit test for the multi-tenant fan-out. Mock providers → plan-only,
# no cluster. Verifies the tenant module fans out per map entry with isolated
# namespaces and wires the gateway/plugin-set.

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "kubectl" {}

variables {
  kubeconfig             = "/dev/null"
  operator_chart_version = "0.1.0"
}

run "fans_out_three_tenants" {
  command = plan

  assert {
    condition     = output.tenant_count == 3
    error_message = "expected the default 3 tenants to fan out"
  }

  assert {
    condition     = output.tenant_namespaces["team-a"] == "team-a"
    error_message = "tenant namespace should default to the tenant name"
  }

  assert {
    condition     = output.tenant_gateways["team-a"] == "team-a"
    error_message = "each tenant should get a gateway named after it"
  }
}

run "scale_one_tenant" {
  command = plan

  variables {
    tenants = {
      only = { environment = "prod", replicas = 5 }
    }
  }

  assert {
    condition     = output.tenant_count == 1
    error_message = "tenant map edit should change the fleet size"
  }
}
