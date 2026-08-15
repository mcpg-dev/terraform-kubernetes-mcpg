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
variable "tenant_namespaces" {
  type        = list(string)
  default     = ["team-a", "team-b"]
  description = "Namespaces Terraform creates as tenancy boundaries; GitOps syncs CRs into them."
}
