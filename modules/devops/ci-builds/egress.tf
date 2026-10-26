# Default-deny plus three doors: DNS and self (baseline), the private gateway (Harbor + the Forgejo
# instance), and the public internet (base images from docker.io, the Rust crate index, toolchain
# downloads). Nothing else — notably no LAN, since `allow_internet` excludes RFC1918.
module "egress_baseline" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "${var.name}-baseline-egress"
}

module "egress_gateway" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "${var.name}-gateway-egress"

  peers = [{
    namespace    = var.gateway_namespace
    pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
    ports        = [{ port = 443 }]
  }]
}

module "egress_internet" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace      = kubernetes_namespace_v1.namespace.metadata[0].name
  name           = "${var.name}-internet-egress"
  allow_internet = true
}
