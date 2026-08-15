output "ready" {
  description = "Names of the applied CRDs. Depend on this from the operator module to enforce CRDs-before-operator ordering."
  value       = [for k, r in kubectl_manifest.crd : r.name]
}

output "kinds" {
  description = "The CRD file stems applied (one per kind)."
  value       = [for f in local.crd_files : trimsuffix(f, ".yaml")]
}
