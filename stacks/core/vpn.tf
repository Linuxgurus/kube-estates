module "wireguard" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/network/wireguard?ref=v0.1.0"

  namespace          = "kube-network-vpn"
  external_address   = var.deployment.network.vpn.external_address
  dns                = var.deployment.network.vpn.dns
  dns_search_domains = var.deployment.network.vpn.dns_search_domains
  peers              = var.deployment.network.vpn.peers

  depends_on = [module.network]
}
