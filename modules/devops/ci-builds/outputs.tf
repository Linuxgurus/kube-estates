output "namespace" {
  description = "Namespace build Jobs are created in."
  value       = kubernetes_namespace_v1.namespace.metadata[0].name
}

output "service_account" {
  description = "The dispatcher's ServiceAccount (named `ci-builder` inside the namespace)."
  value       = kubernetes_service_account_v1.builder.metadata[0].name
}

output "token" {
  description = "Token for `ci-builder`. Paste into the workflow's kubeconfig secret; never commit it."
  value       = kubernetes_secret_v1.builder_token.data["token"]
  sensitive   = true
}
