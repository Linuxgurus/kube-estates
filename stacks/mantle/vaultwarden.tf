module "vaultwarden" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/vaultwarden?ref=v0.1.0"

  namespace   = "vaultwarden"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  image_tag = "1.37.3"

  signups_allowed = true
}
