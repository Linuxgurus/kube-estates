variable "namespace" { type = string }
variable "cert_issuer" { type = string }
variable "name" { default = "seaweedfs" }
variable "helm_repo" { default = "https://seaweedfs.github.io/seaweedfs/helm" }
variable "chart" { default = "seaweedfs" }
variable "visibility" { default = "private" }
variable "domains" { type = map(any) }
variable "data_center" { type = string }
variable "volume_replicas" { default = 6 }
variable "worker_replicas" { default = 6 }
# The Lance Namespace REST endpoint on the S3 gateway, and the `worker-lance` sidecar that serves it.
# Off = neither exists: lancePort 0 makes the chart omit the sidecar, and the gateway listener is
# skipped. A sidecar that cannot register is worse than no sidecar -- it looks like a worker.
variable "lance_enabled" {
  type    = bool
  default = true
}
variable "host_path_prefix" { default = "/ssd" }
variable "helm_version" { default = "4.48.0" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
