# OpenTofu-only overlay (a `.tofu` file is loaded by `tofu`, IGNORED by
# `terraform`) — encrypts state AND plan at rest (OpenTofu >= 1.7).
# This is the "one source tree, two CLIs" mechanism: the .tf baseline stays
# Terraform-valid; this enhancement activates only under OpenTofu.
#
# PBKDF2 here for portability; in production swap the key_provider for
# aws_kms / gcp_kms / openbao. The passphrase is a
# variable — never hardcode a real one; override via TF_VAR_state_passphrase.
terraform {
  encryption {
    key_provider "pbkdf2" "this" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "this" {
      keys = key_provider.pbkdf2.this
    }
    state {
      method = method.aes_gcm.this
    }
    plan {
      method = method.aes_gcm.this
    }
  }
}

variable "state_passphrase" {
  type        = string
  sensitive   = true
  default     = "example-only-change-me-passphrase-0001"
  description = "PBKDF2 passphrase for OpenTofu state encryption. Example default; override via TF_VAR_state_passphrase in real use."
}
