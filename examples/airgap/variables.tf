variable "kubeconfig" {
  type    = string
  default = "~/.kube/config"
}
variable "namespace" {
  type    = string
  default = "mcpg-system"
}
variable "operator_chart_version" {
  type    = string
  default = "0.1.0"
}
variable "operator_airgap_values" {
  type = any
  default = {
    operator = {
      # Offline Sigstore trust root — cosign keyless verification with no
      # network. Create the `mcpg-trust-roots` ConfigMap (trusted_root.json)
      # from your sync station before applying.
      sigstoreTrustRoot = {
        enabled       = true
        configMapName = "mcpg-trust-roots"
        key           = "trusted_root.json"
      }
    }
  }
  description = "Operator chart values enabling the offline Sigstore trust root (+ any air-gap enforcement keys)."
}

# In-cluster OCI mirror Service coordinates (MCPGPluginMirror.spec.endpoint).
variable "mirror_service" {
  type = object({
    namespace   = string
    name        = string
    port        = number
    path_prefix = optional(string)
  })
  default = {
    namespace = "mcpg-system"
    name      = "registry"
    port      = 5000
  }
  description = "In-cluster registry Service the mirror fronts."
}

variable "oci_registry_base" {
  type        = string
  default     = "ghcr.io/mcpg-dev/source-code"
  description = "Registry base every MCPG artefact hangs off (charts at <base>/charts, images at <base>/<name>, plugins at <base>/plugins). Mirrors tools/release/oci-registry.json."
}

# Public registry + namespace the mirror stands in for. The operator rewrites
# upstream plugin refs starting with <registry>/<namespace>/ onto the mirror.
variable "upstream" {
  type = object({
    registry  = string
    namespace = string
  })
  default     = null
  description = "Upstream registry + namespace the mirror rehomes. Null splits oci_registry_base at its host segment; set it when the mirror fronts a base that is not where MCPG publishes."
}

variable "signing_key_secret" {
  type        = string
  default     = "mcpg-plugin-signing-key"
  description = "Secret (operator namespace) holding the Ed25519 release.pub the plugin's signature is verified against — mandatory trust baseline."
}

variable "sql_plugin_digest" {
  type        = string
  default     = "sha256:1111111111111111111111111111111111111111111111111111111111111111"
  description = "Digest of the SQL plugin artefact (digest-pinned, no tags)."
}
variable "gateway_image_tag" {
  type    = string
  default = "v1.0.0-rc.17"
}
