resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

module "metrics_server" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/monitoring/metrics_server?ref=v0.1.0"
  depends_on = [module.prometheus]
  namespace  = "monitoring"
}

module "smartctl" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/monitoring/smartctl?ref=v0.1.0"
  depends_on = [module.prometheus]
  namespace  = "monitoring"
}

module "prometheus" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/monitoring/prometheus?ref=v0.1.0"
  namespace   = "monitoring"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  gateway_name      = module.network.gateway_name
  gateway_namespace = module.network.gateway_namespace

  # Absent keys leave Alertmanager on its silent default receiver.
  pushover_user_key     = try(var.deployment.monitoring.pushover.user_key, "")
  pushover_token        = try(var.deployment.monitoring.pushover.token, "")
  slack_webhook_routine = try(var.deployment.monitoring.slack.webhook_routine, "")
  slack_webhook_mirror  = try(var.deployment.monitoring.slack.webhook_mirror, "")
}
