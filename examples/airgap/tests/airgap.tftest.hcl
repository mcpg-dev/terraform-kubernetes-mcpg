# Offline test: the plugin is digest-pinned to its UPSTREAM ref + mirror-rehomed
# via mirrorRef (the operator rewrite needs the upstream ref, not the mirror
# host), carries the mandatory signingKeyRef, and the gateway image (pulled
# directly) points at the in-cluster mirror host.

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "kubectl" {}

variables {
  kubeconfig             = "/dev/null"
  operator_chart_version = "0.1.0"
}

run "airgap_refs_are_contract_correct" {
  command = plan

  # Plugin image is the UPSTREAM public ref (so the operator's mirrorRef rewrite
  # matches), NOT the mirror host.
  assert {
    condition     = startswith(output.plugin_image, "ghcr.io/mcpg-dev/source-code/")
    error_message = "plugin image must be the upstream ref so mirrorRef rewrite applies (mirror host would short-circuit to NotApplicable)"
  }

  assert {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", output.plugin_image))
    error_message = "plugin must be digest-pinned (no tags) in air-gap"
  }

  assert {
    condition     = output.plugin_mirror_ref == "cluster-mirror"
    error_message = "plugin must reference the MCPGPluginMirror for rehoming"
  }

  # The mandatory Ed25519 trust baseline is present.
  assert {
    condition     = output.plugin_signing_key_secret == "mcpg-plugin-signing-key"
    error_message = "plugin trust must carry the mandatory signingKeyRef"
  }

  # The gateway image (pulled directly by kubelet) resolves to the mirror host.
  assert {
    condition     = startswith(output.gateway_image_repository, "registry.mcpg-system.svc.cluster.local:5000/")
    error_message = "gateway image must come from the in-cluster mirror host"
  }
}

run "mirror_spec_is_schema_shaped" {
  command = plan

  # endpoint is the structured object (service{namespace,name,port}+insecure),
  # NOT a host:port string.
  assert {
    condition     = module.airgap.mirror_host == "registry.mcpg-system.svc.cluster.local:5000"
    error_message = "mirror_host must be the in-cluster Service DNS name:port"
  }
  assert {
    condition     = module.airgap.mirror_manifest.spec.endpoint.service.port == 5000
    error_message = "MCPGPluginMirror.spec.endpoint must be an object with service.{namespace,name,port}, not a string"
  }
  assert {
    condition     = module.airgap.mirror_manifest.spec.endpoint.service.name == "registry" && module.airgap.mirror_manifest.spec.endpoint.service.namespace == "mcpg-system"
    error_message = "endpoint.service must carry name + namespace"
  }
  # upstream is { registry, namespace } — not { prefix }.
  assert {
    condition     = module.airgap.mirror_manifest.spec.upstream.registry == "ghcr.io" && module.airgap.mirror_manifest.spec.upstream.namespace == "mcpg-dev/source-code"
    error_message = "MCPGPluginMirror.spec.upstream must be { registry, namespace }, not { prefix }"
  }
}

# The registry base is a knob, and the mirror's upstream is derived from it by
# splitting at the HOST segment. A ref that kept the literal would still plan
# clean while the rewrite silently stopped matching (`NotApplicable`).
run "registry_base_repoints_upstream_and_refs" {
  command = plan

  variables {
    oci_registry_base = "registry.example.test/acme"
  }

  assert {
    condition     = startswith(output.plugin_image, "registry.example.test/acme/plugins/sql@")
    error_message = "plugin image does not compose from oci_registry_base"
  }

  assert {
    condition     = module.airgap.mirror_manifest.spec.upstream.registry == "registry.example.test" && module.airgap.mirror_manifest.spec.upstream.namespace == "acme"
    error_message = "upstream does not split oci_registry_base at its host segment"
  }

  assert {
    condition     = endswith(output.gateway_image_repository, "/acme/gateway")
    error_message = "gateway image does not compose from oci_registry_base"
  }
}
