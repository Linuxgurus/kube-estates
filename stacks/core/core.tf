module "network" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/network?ref=v0.1.0"
  internal_dns   = var.deployment.network.internal_dns
  metal_networks = var.deployment.network.metal_networks
}


module "cert_man" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/cert_manager?ref=v0.1.0"
  acme_email = var.deployment.cert_manager.acme_email

  dns01 = {
    AWS_ACCESS_KEY_ID     = var.deployment.cert_manager.dns01.access_key
    AWS_SECRET_ACCESS_KEY = var.deployment.cert_manager.dns01.secret_key
    AWS_REGION            = var.deployment.cert_manager.dns01.region
    R53_ZONEID            = var.deployment.cert_manager.dns01.zone_id
  }
}
