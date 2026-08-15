# Offline unit test for the module wiring + the gateway config builder.
# Uses mock providers so it runs with no cluster (plan-only). Validates that
# the config builder assembles spec.config correctly and the CR wiring holds.
#
# Run:  tofu init -backend=false && tofu test     (from this example dir)

mock_provider "kubectl" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}

variables {
  kubeconfig             = "/dev/null"
  operator_chart_version = "0.1.0"
}

run "config_builder_assembles_spec" {
  command = plan

  assert {
    condition     = output.gateway_manifest.kind == "MCPGGateway"
    error_message = "expected kind MCPGGateway"
  }

  assert {
    condition     = output.gateway_manifest.apiVersion == "mcpg.dev/v1alpha1"
    error_message = "expected apiVersion mcpg.dev/v1alpha1"
  }

  assert {
    condition     = output.gateway_manifest.metadata.namespace == "mcpg-system"
    error_message = "gateway namespace not wired through"
  }

  # Typed section flows into spec.config via the builder (audit uses a sinks list).
  assert {
    condition     = output.gateway_manifest.spec.config.governance.audit.sinks[0].kind == "dev.mcpg.builtin.audit.local-file"
    error_message = "typed governance.audit.sinks missing from built config"
  }

  # Required CRD field present.
  assert {
    condition     = output.gateway_manifest.spec.image.repository == "ghcr.io/mcpg-dev/source-code/gateway"
    error_message = "image.repository not wired"
  }

  assert {
    condition     = output.gateway_manifest.spec.replicas == 2
    error_message = "replicas not wired"
  }
}

run "config_fingerprint_is_sha256" {
  command = plan

  assert {
    condition     = length(output.gateway_config_fingerprint) == 64
    error_message = "config fingerprint should be a 64-char sha256 hex digest"
  }
}

run "all_nine_crds_planned" {
  command = plan

  assert {
    condition     = length(output.crd_kinds) == 9
    error_message = "expected all 9 MCPG CRDs to be planned"
  }
}

# The registry base is a knob, so a build that repoints it must repoint every
# artefact ref. A ref that kept the literal would still plan clean and pull
# from the old registry.
run "registry_base_repoints_the_image" {
  command = plan

  variables {
    oci_registry_base = "registry.example.test/acme"
  }

  assert {
    condition     = output.gateway_manifest.spec.image.repository == "registry.example.test/acme/gateway"
    error_message = "gateway image.repository does not compose from oci_registry_base"
  }
}
