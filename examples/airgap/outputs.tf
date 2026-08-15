output "mirror_host" {
  value = module.airgap.mirror_host
}

output "plugin_image" {
  description = "The plugin's OCI image — the UPSTREAM public ref; the operator rehomes it onto the mirror via mirrorRef at pull."
  value       = module.plugin_sql.manifest.spec.oci.image
}

output "plugin_mirror_ref" {
  value = module.plugin_sql.manifest.spec.oci.mirrorRef.name
}

output "plugin_signing_key_secret" {
  description = "The mandatory Ed25519 signing-key Secret the plugin's trust references."
  value       = module.plugin_sql.manifest.spec.trust.signingKeyRef.secretName
}

output "gateway_image_repository" {
  value = module.gateway.manifest.spec.image.repository
}
