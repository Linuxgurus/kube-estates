module "ingress_baseline" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/network/firewalls/policy?ref=v0.1.0"
  direction = "ingress"

  namespace = var.namespace
  name      = "kube-storage-baseline-ingress"

  peers = [
    {
      namespace    = var.gateway_namespace
      pod_selector = { "gateway.networking.k8s.io/gateway-name" = var.gateway_name }
      ports        = [{ port = 8333 }, { port = 9333 }, { port = 9101 }]
    },
  ]
}
