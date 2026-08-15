output "name" {
  description = "MCPGGateway name."
  value       = var.name
}

output "namespace" {
  description = "Namespace."
  value       = var.namespace
}

output "config_fingerprint" {
  description = "Local SHA-256 of the rendered spec.config — a client-side change detector (distinct from the operator's status config_hash)."
  value       = sha256(jsonencode(local.built_config))
}

output "manifest" {
  description = "The rendered MCPGGateway manifest (object). Exposed for assertion in `terraform test`."
  value       = local.manifest
}
