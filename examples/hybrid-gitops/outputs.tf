# The handoff contract: everything GitOps needs to reference
# rather than re-declare. Wire these into an Argo CD ApplicationSet / Flux
# Kustomization that owns the layer-3 CRs.
output "operator_namespace" {
  value = module.operator.namespace
}

output "tenant_namespaces" {
  value = sort([for ns in kubernetes_namespace.tenant : ns.metadata[0].name])
}

output "cluster_default_revocation_list" {
  value = module.trust.revocation_list_name
}

output "signing_key_secret_ref" {
  description = "Signing-key secretRef for plugin trust (name/key only — no bytes)."
  value       = module.trust.signing_key_secret_ref
}
