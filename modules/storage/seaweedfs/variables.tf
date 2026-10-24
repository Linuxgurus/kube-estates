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
# Mint a shared HMAC key and mount it on the admin (verifier) and the worker
# (signer) only. Required from chart/image 4.49 on: without a key the admin's
# worker gRPC service admits local callers only, so remote workers are refused.
variable "admin_peer_auth" {
  type    = bool
  default = true
}

variable "image_tag" {
  type    = string
  default = "4.49-ga9ba38385"
}

# Temporary pins so the auth-bearing pair can move ahead of the storage core.
# Empty = use image_tag. The admin/worker pair is the only place 4.49 adds new
# behaviour; master/volume/filer/s3 are a straight version bump and can follow
# once the pair is proven.
variable "admin_image_override" {
  type    = string
  default = ""
}

variable "worker_image_override" {
  type    = string
  default = ""
}
variable "host_path_prefix" { default = "/ssd" }
variable "helm_version" { default = "4.48.0" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
