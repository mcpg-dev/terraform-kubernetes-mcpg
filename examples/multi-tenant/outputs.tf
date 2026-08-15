output "tenant_namespaces" {
  description = "Map of tenant name → namespace."
  value       = { for k, t in module.tenant : k => t.namespace }
}

output "tenant_count" {
  value = length(module.tenant)
}

output "tenant_gateways" {
  value = { for k, t in module.tenant : k => t.gateway_name }
}
