variable "argo_namespace" { type = string }
variable "name" { type = string }
variable "namespace" { default = "" }
variable "create_namespace" { default = false }
variable "project" { default = "" }
variable "aoa_name" { default = "" }

variable "deployer_repo" { type = string }
variable "deployer_path" { type = string }

# Cluster-scoped kinds the project may manage. Empty denies all of them.
variable "cluster_resource_whitelist" { default = [] }

# Whether a sync with NO objects is allowed to succeed. With `prune = true` above, `true` means an
# empty render deletes everything the application manages; `false` makes ArgoCD refuse instead.
# Default false: the failure mode of `true` is a deleted deployment, the failure mode of `false`
# is a sync that refuses until someone looks.
variable "allow_empty" {
  type    = bool
  default = false
}
