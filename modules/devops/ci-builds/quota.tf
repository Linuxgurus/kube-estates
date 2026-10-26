# Two ceilings, and they answer different questions.
#
# The LimitRange answers "this pod declared no resources — what now?". Without it, a Dockerfile
# built by a pod with no resources stanza is unbounded, and we are back to the DinD failure mode
# with extra steps. With it, every container gets a limit whether or not the Job bothered.
#
# The ResourceQuota answers "how much can this namespace take from the cluster at once?". Five
# concurrent builds at 2 CPU each is a deliberate number: it is smaller than the node's capacity,
# so a saturated build queue degrades the builds, not the cluster.
resource "kubernetes_limit_range_v1" "builds" {
  metadata {
    name      = "${var.name}-defaults"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = var.default_limits.default_cpu
        memory = var.default_limits.default_mem
      }

      default_request = {
        cpu    = var.default_limits.default_req_cpu
        memory = var.default_limits.default_req_mem
      }

      max = {
        cpu    = var.default_limits.max_cpu
        memory = var.default_limits.max_mem
      }
    }
  }
}

resource "kubernetes_resource_quota_v1" "builds" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  spec {
    hard = {
      "count/jobs.batch" = var.quota.jobs
      "requests.cpu"     = var.quota.requests_cpu
      "requests.memory"  = var.quota.requests_mem
      "limits.cpu"       = var.quota.limits_cpu
      "limits.memory"    = var.quota.limits_mem
    }
  }
}
