# The dispatcher's identity: a CI job submits a build, waits for it, and relays its log. That is
# the entire permission set — it can create and watch Jobs here and read their pods' logs, and
# nothing else. It cannot read Secrets (so it cannot lift the registry credentials a build mounts),
# cannot exec into a build, and cannot touch another namespace.
resource "kubernetes_service_account_v1" "builder" {
  metadata {
    name      = "ci-builder"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }
}

resource "kubernetes_role_v1" "builder" {
  metadata {
    name      = "ci-builder"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["create", "get", "list", "watch", "delete"]
  }

  # Watching a Job's outcome is not enough to relay its output: that needs the pods it creates.
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "builder" {
  metadata {
    name      = "ci-builder"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.builder.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.builder.metadata[0].name
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }
}

# A long-lived token rather than a projected one: the dispatcher is a CI job container created by
# the runner's docker daemon, which has no service-account projection to inherit. The token travels
# to the workflow as a Forgejo secret (a kubeconfig), never as a mounted file.
resource "kubernetes_secret_v1" "builder_token" {
  metadata {
    name      = "ci-builder-token"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.builder.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}
