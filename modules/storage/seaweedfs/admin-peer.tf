# The admin plane's gRPC services admit a peer only two ways: a TLS client
# certificate the server itself verified, or a Bearer token signed by
# jwt.filer_signing.key. With NO key they admit local callers alone -- so a
# worker on another node cannot register, and that is the whole reason this
# key has to exist on both ends.
#
# It is mounted on the admin (verifier) and the worker (signer), nowhere else.
# The FILER reads the same key name for its own IAM gRPC service: mounting this
# Secret cluster-wide would start enforcing it there, which is a different
# decision with a different blast radius (every direct filer writer).
resource "random_password" "admin_peer" {
  count   = var.admin_peer_auth ? 1 : 0
  length  = 48
  special = false
}

resource "kubernetes_secret_v1" "admin_peer" {
  count = var.admin_peer_auth ? 1 : 0

  metadata {
    name      = "${var.name}-admin-peer"
    namespace = var.namespace
  }

  # viper looks for a config file named `security` in /etc/seaweedfs, which is
  # exactly where the chart puts its own copy; this mounts at the same path.
  data = {
    "security.toml" = "[jwt.filer_signing]\nkey = \"${random_password.admin_peer[0].result}\"\nexpires_after_seconds = 3600\n"
  }
}

locals {
  admin_peer_volumes = var.admin_peer_auth ? yamlencode([{
    name = "admin-peer"
    secret = {
      secretName = "${var.name}-admin-peer"
      items      = [{ key = "security.toml", path = "security.toml" }]
    }
  }]) : ""

  admin_peer_mounts = var.admin_peer_auth ? yamlencode([{
    name      = "admin-peer"
    mountPath = "/etc/seaweedfs/security.toml"
    subPath   = "security.toml"
    readOnly  = true
  }]) : ""
}
