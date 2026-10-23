module "ingress_longhorn_system" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/network/firewalls/policy?ref=v0.1.0"
  direction = "ingress"

  namespace = var.longhorn_namespace
  name      = "longhorn-system-ingress"
}
