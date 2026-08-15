# modules/trust-bootstrap — seed cluster-scoped trust: the `cluster-default`
# MCPGRevocationList, plus a pass-through of the plugin signing-key secretRef.
#
# The signing-key bytes are NEVER read into Terraform state —
# this module only references the Secret by name/key and forwards it to plugin
# modules, which wire it into MCPGPlugin.spec.trust.signingKeyRef.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

variable "revocation_list_name" {
  type    = string
  default = "cluster-default"
}
variable "revocations" {
  type        = list(any)
  default     = []
  description = "Revocation entries: { artifactSha256 (64 hex, case-insensitive — the operator lowercases for dedup), reason (non-empty) }."
}
variable "issued_at" {
  type    = string
  default = null
}
variable "signing_key_secret_ref" {
  type        = object({ secretName = string, key = optional(string, "release.pub") })
  default     = null
  description = "Reference to the plugin signing-key Secret, shaped to drop straight into MCPGPlugin.spec.trust.signingKeyRef ({ secretName, key }). Bytes are never read into state."
}

locals {
  manifest = {
    apiVersion = "mcpg.dev/v1alpha1"
    kind       = "MCPGRevocationList"
    metadata   = { name = var.revocation_list_name }
    spec = merge(
      { version = 1, revocations = var.revocations },
      var.issued_at == null ? {} : { issuedAt = var.issued_at },
    )
  }
}

resource "kubectl_manifest" "revocation_list" {
  yaml_body         = yamlencode(local.manifest)
  server_side_apply = true
  force_conflicts   = true
}

output "revocation_list_name" {
  value = var.revocation_list_name
}
output "signing_key_secret_ref" {
  description = "Pass-through of the signing-key secretRef for plugin modules."
  value       = var.signing_key_secret_ref
}
output "manifest" { value = local.manifest }
