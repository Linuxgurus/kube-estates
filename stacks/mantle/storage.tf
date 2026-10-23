module "seaweedfs_admin" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/storage/seaweedfs_admin?ref=v0.1.0"

  namespace   = "kube-storage"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  gateway_name      = "private"
  gateway_namespace = "kube-network"
}
