output "ready" {
  description = "Readiness gate — populated only after the Helm release finishes waiting (Deployment Available). Use `depends_on = [module.operator]` on CR modules."
  value       = helm_release.operator.status
}

output "namespace" {
  description = "Namespace the operator runs in."
  value       = helm_release.operator.namespace
}

output "release_name" {
  description = "Helm release name."
  value       = helm_release.operator.name
}

output "values" {
  description = "The merged chart values (presets + cert-manager/webhook + overrides). Exposed for inspection/tests."
  value       = local.values
}
