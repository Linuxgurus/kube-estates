module "harbor_setup" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/devops/harbor/mantle?ref=v0.1.0"
  projects      = var.deployment.harbor.projects
  domain        = var.deployment.cluster.domains.private
  oauth2_server = "auth.${var.deployment.cluster.domains.private}"
}

module "argo_setup" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/devops/argo/mantle?ref=v0.1.0"
  namespace     = var.deployment.argo.namespace
  oauth2_server = "auth.${var.deployment.cluster.domains.private}"
  domain        = var.deployment.cluster.domains.private
  deploy_key    = var.deployment.argo.deploy_key
  repo          = var.deployment.argo.repo
}

# The CI half: a Harbor push robot, and its credentials written onto the listed repos as Actions
# secrets so a workflow can `docker login` and push.
#
# No `depends_on = [module.harbor_setup]`, deliberately. The robot lives in Harbor's default
# `library` project, which Harbor creates itself, so there is nothing in this stack to order
# against -- and the dependency could not be declared *inside* the module anyway, since
# `harbor_setup` is declared at this scope (referencing it from the module would be a hard
# "undeclared module" error, the E17-1 class; see T3.3/O20-3).
#
# The `forgejo` provider it uses is configured in providers.tf from the chart-minted
# `forgejo-admin` Secret -- the instance belongs to `core` now, so this stack only reads it.
module "forgejo_setup" {
  source = "git::https://git.vn.linuxguru.net/Linuxguru/k8s-terraform.git//modules/devops/forgejo/mantle?ref=v0.1.0"

  registry_repos = var.forgejo_registry_repos
}
