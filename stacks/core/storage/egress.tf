module "egress_baseline" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/network/firewalls/policy?ref=v0.1.0"
  direction = "egress"

  namespace = var.namespace
  name      = "kube-storage-baseline-egress"
}

# Cluster-wide VolumeSnapshot reconciliation, plus its leader-election lease.
module "egress_snapshot_controller" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/network/firewalls/policy?ref=v0.1.0"
  direction = "egress"

  namespace     = var.namespace
  name          = "snapshot-controller-egress"
  pod_selector  = { "app.kubernetes.io/name" = "snapshot-controller" }
  allow_k8s_api = true
}
