output "gateway_manifest" {
  description = "The rendered MCPGGateway manifest (for assertions / inspection)."
  value       = module.gateway.manifest
}

output "gateway_config_fingerprint" {
  description = "Client-side SHA-256 of the gateway's built config."
  value       = module.gateway.config_fingerprint
}

output "operator_namespace" {
  description = "Namespace the operator runs in."
  value       = module.operator.namespace
}

output "crd_kinds" {
  description = "CRD kinds applied."
  value       = module.crds.kinds
}
