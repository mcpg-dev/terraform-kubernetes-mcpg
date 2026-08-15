# modules/observability — a config helper that assembles the gateway's
# `monitoring` block (ServiceMonitor / PrometheusRule toggles). Pure I/O — no
# resources; feed its `monitoring` output into the gateway module so the
# operator emits the Prometheus-operator objects.
terraform {
  required_version = ">= 1.7.0"
}

variable "service_monitor" {
  type    = bool
  default = true
}
variable "prometheus_rule" {
  type    = bool
  default = false
}
variable "interval" {
  type    = string
  default = "30s"
}
variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels (e.g. release=kube-prometheus-stack) so Prometheus selects the objects."
}

locals {
  monitoring = merge(
    { serviceMonitor = { enabled = var.service_monitor, interval = var.interval, labels = var.labels } },
    var.prometheus_rule ? { prometheusRule = { enabled = true, labels = var.labels } } : {},
  )
}

output "monitoring" {
  description = "Feed into the gateway module's `monitoring` input."
  value       = local.monitoring
}
