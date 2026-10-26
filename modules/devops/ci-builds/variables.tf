# Image builds happen here, not in the runner.
#
# WHY A SEPARATE NAMESPACE: a build pod runs arbitrary repo code with a Dockerfile's worth of
# privilege (buildah needs mount namespaces and a writable graph root). Keeping it out of the
# runner's namespace means the blast radius of a build pod is exactly this namespace: its own
# quota, its own limit range, its own egress.
#
# The thing this namespace exists to avoid, measured 2026-10-25 (Linuxguru/kube-estates#21): the
# runner's DinD sidecar is a privileged pod, so it inherits the HOST cgroup namespace and puts the
# jobs it starts in /sys/fs/cgroup/docker/* — a sibling of kubepods.slice. Nothing it starts is
# covered by the pod's limits or visible to cAdvisor. A pod here is an ordinary pod: its limits
# bind, its CPU is attributed, its egress is governed.
variable "namespace" { default = "ci-builds" }
variable "name" { default = "ci-builds" }

# Harbor and the Forgejo instance resolve to the same private-gateway VIP, so one peer covers
# both: build pods must clone source and push images, and admitting the LAN directly would be a
# wider rule than either needs.
variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

# Ceilings. A build pod that asks for nothing still gets a limit (LimitRange default), and the
# namespace as a whole cannot exceed the quota — so one runaway build can never take a node, which
# is precisely what the DinD path could not promise.
variable "quota" {
  description = "Hard limits for the whole namespace."
  type = object({
    jobs         = string
    requests_cpu = string
    requests_mem = string
    limits_cpu   = string
    limits_mem   = string
  })
  default = {
    jobs         = "5"
    requests_cpu = "8"
    requests_mem = "16Gi"
    limits_cpu   = "16"
    limits_mem   = "32Gi"
  }
}

variable "default_limits" {
  description = "Applied to any container that declares none. Pods may set less, never more than the max."
  type = object({
    default_cpu     = string
    default_mem     = string
    max_cpu         = string
    max_mem         = string
    default_req_cpu = string
    default_req_mem = string
  })
  default = {
    default_cpu     = "2"
    default_mem     = "4Gi"
    max_cpu         = "4"
    max_mem         = "8Gi"
    default_req_cpu = "500m"
    default_req_mem = "1Gi"
  }
}
