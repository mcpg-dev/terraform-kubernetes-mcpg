# modules/plugin — register an MCPGPlugin in the cluster catalog (cluster-scoped).
# All of oci / pluginClass / pluginId / trust / version are required by the CRD.
# trust.signingKeyRef (Ed25519) is the MANDATORY baseline — cosign/SLSA/digest
# are additive, not substitutes. A digest pin lives under oci.image, not trust.
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubectl = { source = "alekc/kubectl", version = ">= 2.0" }
  }
}

variable "name" { type = string }
variable "plugin_id" {
  type        = string
  description = "Dotted plugin id (e.g. dev.mcpg.backend.sql)."
}
variable "plugin_class" { type = string }
variable "plugin_version" {
  type        = string
  description = "Plugin version (named plugin_version, not version — `version` is a reserved module meta-argument)."
}
variable "oci" {
  type        = any
  description = "OCI source: { image, mirrorRef?, pullSecretRef? }."
}
variable "trust" {
  type        = any
  description = <<-EOT
    Trust policy: { signingKeyRef = { secretName, key? }, cosignIdentity?,
    slsaProvenance? }. `signingKeyRef` is REQUIRED (the Ed25519 signature gate
    every plugin must pass); cosignIdentity / slsaProvenance are optional
    additive layers. The artifact digest pin goes under `oci.image`, not here.
  EOT
}
variable "labels" {
  type    = map(string)
  default = {}
}
variable "extra_spec" {
  type    = any
  default = {}
}

locals {
  manifest = {
    apiVersion = "mcpg.dev/v1alpha1"
    kind       = "MCPGPlugin"
    metadata   = { name = var.name, labels = var.labels }
    spec = merge({
      pluginId    = var.plugin_id
      pluginClass = var.plugin_class
      version     = var.plugin_version
      oci         = var.oci
      trust       = var.trust
    }, var.extra_spec)
  }
}

resource "kubectl_manifest" "plugin" {
  yaml_body         = yamlencode(local.manifest)
  server_side_apply = true
  force_conflicts   = true
}

output "name" { value = var.name }
output "manifest" { value = local.manifest }
