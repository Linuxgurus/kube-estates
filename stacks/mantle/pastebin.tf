module "pastebin" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/pastebin?ref=v0.1.0"

  # Public app: anyone with a share link can download it from the internet.
  domain      = var.deployment.cluster.domains.public
  cert_issuer = var.deployment.cert_manager.external_issuer

  # authentik stays on the private gateway (LAN/VPN), so only those users can sign in and
  # create shares -- which is what "authorized users" means here.
  oidc_issuer_base = var.deployment.auth.server

  gateway_name = "public"
}
