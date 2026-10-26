resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = var.namespace
    labels = {
      # Same marker the network modules use to find the pods a policy governs.
      "app.kubernetes.io/part-of" = var.name
    }
  }
}
