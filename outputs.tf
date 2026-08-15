output "operator_namespace" {
  description = "Namespace the operator runs in."
  value       = module.operator.namespace
}

output "operator_values" {
  description = "Merged operator chart values (sizing preset + cert-manager/webhook + overrides)."
  value       = module.operator.values
}

output "gateway_name" {
  description = "Gateway name, if a gateway was created."
  value       = try(module.gateway[0].name, null)
}

output "gateway_manifest" {
  description = "Rendered MCPGGateway manifest, if a gateway was created."
  value       = try(module.gateway[0].manifest, null)
}

output "plugin_set_name" {
  description = "Plugin-set name, if one was created."
  value       = try(module.plugin_set[0].name, null)
}

output "crd_kinds" {
  description = "CRD kinds applied."
  value       = module.crds.kinds
}
