variable "crds_dir" {
  type        = string
  default     = null
  description = <<-EOT
    Directory containing the split-by-kind MCPG CRD YAMLs (one CRD per file).
    The module vendors the generated schema snapshot and defaults this to
    "$${path.module}/crds"; point it elsewhere to supply your own copies.
  EOT
}
