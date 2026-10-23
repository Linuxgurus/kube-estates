module "grafana_oidc" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/monitoring/grafana_oidc?ref=v0.1.0"
  namespace = "monitoring"
  domain    = var.deployment.cluster.domains.private
}

# Alertmanager's own UI, so silence links in notifications resolve from a phone.
module "alertmanager" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/monitoring/alertmanager?ref=v0.1.0"

  namespace   = "monitoring"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer
}
