locals {
  fqdn       = coalesce(var.hostname, "${var.name}.${var.domain}")
  labels     = { "app.kubernetes.io/name" = var.name, "app.kubernetes.io/part-of" = "agent" }
  health_url = coalesce(one([for u in [var.brain_health_url] : u if u != ""]), replace(var.brain_url, "/mcp", "/health"))

  # ★ MAIL GOES IN-CLUSTER, NEVER VIA THE PUBLIC NAME. The public host resolves to the LAN gateway,
  # which a pod has no route to; `bin/mail`'s own default is that public name.
  brain_root = trimsuffix(var.brain_url, "/mcp")
  mail_me    = var.mail_me == "" ? trimsuffix(var.name, "-hand") : var.mail_me

  # ★ THE PEN, BY FILE. ONE path, used by the secret mount, the mount_path and FORGEJO_TOKEN_FILE, so
  # moving it is a single edit instead of three that can drift apart.
  forgejo_token_path = "/home/node/.cline/hands/secrets/forgejo-token"
}

data "kubernetes_service_v1" "repo_gateway" {
  count = var.repo_host == "" ? 0 : 1

  metadata {
    name      = var.repo_gateway_service != "" ? var.repo_gateway_service : "${var.gateway_name}-${var.gateway_name}"
    namespace = var.gateway_namespace
  }
}

# The finger's MCP config: the SAME store as the hand, reached in-namespace. One brain per room is the
# whole point of the move; a config pointing at another namespace would undo it quietly.
resource "kubernetes_config_map_v1" "mcp" {
  metadata {
    name      = "${var.name}-mcp"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "cline_mcp_settings.json" = jsonencode({
      mcpServers = { ellmephant = { transport = { type = "streamableHttp", url = var.brain_url } } }
    })
  }
}

resource "kubernetes_deployment_v1" "hand" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    # ONE, serial by design: one hand, one data dir, one hub port. The cross-machine serialization is
    # the store claim; the local lock is the same-machine fast path.
    replicas = 1

    # ★ RECREATE, NOT ROLLINGUPDATE (2026-10-18). The home claim is RWO, so a rolling update
    # deadlocks: the new pod cannot attach the volume while the old pod holds it, and the old pod is
    # not retired until the new one is Ready. Measured live — `FailedAttachVolume: Volume is already
    # used by pod(s) stet-hand-…` — and the fix is to stop the old pod BEFORE starting the new one.
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        # ★ THE NAME MUST MEAN SOMETHING IN HERE. `repo_host` is a public name: outside the cluster it
        # resolves to the LAN VIP, which a pod cannot route. The gateway's ClusterIP is what a pod CAN
        # reach, and keeping the NAME means Host and SNI stay right — so the certificate validates and
        # Forgejo never learns that a tenant exists.
        dynamic "host_aliases" {
          for_each = var.repo_host == "" ? [] : [1]

          content {
            ip        = data.kubernetes_service_v1.repo_gateway[0].spec[0].cluster_ip
            hostnames = [var.repo_host]
          }
        }

        service_account_name = kubernetes_service_account_v1.hand.metadata[0].name

        security_context {
          fs_group = 1000
        }

        container {
          name  = "handd"
          image = "${var.image_repository}:${var.image_tag}"

          image_pull_policy = "Always"

          command = ["/home/node/cline-home/bin/stet-hand", "--daemon"]

          resources {
            requests = { cpu = var.cpu_request, memory = var.memory_request }
            limits   = { memory = var.memory_limit }
          }

          # LIVENESS IS A HEARTBEAT, not a port. The daemon touches $HAND_DIR/heartbeat on every poll
          # (<= 30s); a wedged process stops touching it. A port check cannot see that failure — this
          # morning's hub was listening the whole time it could not reach the store.
          # ★ THE PROBE MUST USE WHAT THE IMAGE HAS. The first version shelled out to `stat`, which
          # this image does not ship (no coreutils, no curl, no kill) — a probe that cannot run is a
          # probe that reads "healthy". Node is guaranteed: it is the runtime the image is built on.
          liveness_probe {
            exec {
              command = ["/usr/local/bin/node", "-e", "process.exit(Date.now() - require('fs').statSync('/home/node/.cline/hand/heartbeat').mtimeMs < 120000 ? 0 : 1)"]
            }

            initial_delay_seconds = 20
            period_seconds        = 30
            failure_threshold     = 3
          }

          env {
            name  = "HOME"
            value = "/home/node"
          }

          env {
            name  = "CLINE_HOME"
            value = "/home/node/cline-home"
          }

          env {
            name  = "ELLMEPHANT_URL"
            value = var.brain_url
          }

          env {
            name  = "MAIL_URL"
            value = local.brain_root
          }

          env {
            name  = "MAIL_ME"
            value = local.mail_me
          }

          # The finger's own ceiling, and the pod's active deadline is longer than this.
          env {
            name  = "HAND_TIMEOUT"
            value = "3600"
          }

          # ★ NO HUB (2026-10-18). Fingers are 3-second runs, one at a time, so a shared hub buys a
          # warm cache and costs a long-lived connector that can wedge — which is exactly what
          # happened at 06:30. Measured: hubless answered in the same 3s and left no hub process.
          env {
            name  = "CLINE_SESSION_BACKEND_MODE"
            value = "local"
          }

          # ★ AND NO SELF-UPDATING BINARY. The image shipped cline 3.0.71 and an unattended
          # `npm update -g cline` replaced it under a running hub (the hub PIDs changed mid-session).
          # A hand whose binary can change without a deploy is not something to reason about.
          env {
            name  = "CLINE_NO_AUTO_UPDATE"
            value = "1"
          }

          env {
            name = "DEEPSEEK_API_KEY"

            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.model_key_field
              }
            }
          }

          dynamic "env" {
            for_each = var.identity == "" ? [] : [var.identity]

            content {
              name  = "ELLMEPHANT_IDENTITY"
              value = env.value
            }
          }

          dynamic "env" {
            for_each = var.identity == "" ? [] : [1]

            content {
              name = "ELLMEPHANT_IDENTITY_SECRET"

              value_from {
                secret_key_ref {
                  name = var.secret_name
                  key  = var.identity_secret_field
                }
              }
            }
          }

          # ★ THE PEN, BY FILE. A hand that does repo work needs its own credential, and it is mounted as
          # a FILE, not an env: an env is inherited by every child, including a finger's shell. The
          # askpass helper prints it for the prompt git passes it (see bin/git-askpass).
          dynamic "env" {
            for_each = var.forgejo_token_field == "" ? [] : [1]

            content {
              name  = "FORGEJO_TOKEN_FILE"
              value = local.forgejo_token_path
            }
          }

          dynamic "env" {
            for_each = var.forgejo_token_field == "" ? [] : [1]

            content {
              name  = "GIT_ASKPASS"
              value = "/home/node/cline-home/bin/git-askpass"
            }
          }

          dynamic "env" {
            for_each = var.forgejo_token_field == "" ? [] : [1]

            content {
              name  = "GIT_TERMINAL_PROMPT"
              value = "0"
            }
          }

          dynamic "volume_mount" {
            for_each = var.home_claim == "" ? [] : [var.home_claim]

            content {
              name       = "home"
              mount_path = "/home/node/cline-home"
            }
          }

          volume_mount {
            name       = "mcp-config"
            mount_path = "/home/node/.cline/hands/settings/cline_mcp_settings.json"
            sub_path   = "cline_mcp_settings.json"
          }

          dynamic "volume_mount" {
            for_each = var.forgejo_token_field == "" ? [] : [1]

            content {
              name       = "forgejo-token"
              mount_path = local.forgejo_token_path
              sub_path   = "forgejo-token"
              read_only  = true
            }
          }

          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/cline-home/.tmp"
          }
        }

        dynamic "volume" {
          for_each = var.home_claim == "" ? [] : [var.home_claim]

          content {
            name = "home"

            persistent_volume_claim {
              claim_name = volume.value
            }
          }
        }

        volume {
          name = "mcp-config"

          config_map {
            name = kubernetes_config_map_v1.mcp.metadata[0].name
          }
        }

        # ★ THE PEN AS A FILE. Only the one key, so the pod never sees the rest of the Secret; absent
        # entirely when no forgejo token is configured, which is what keeps a room without a repo
        # able to start.
        dynamic "volume" {
          for_each = var.forgejo_token_field == "" ? [] : [1]

          content {
            name = "forgejo-token"

            secret {
              secret_name = var.secret_name

              items {
                key  = var.forgejo_token_field
                path = "forgejo-token"
              }
            }
          }
        }

        volume {
          name = "ephemeral"

          empty_dir {
            medium     = "Memory"
            size_limit = "512Mi"
          }
        }
      }
    }
  }
}

# ★ A NAMED SERVICE ACCOUNT, NOT `default`. Everything here that never asked for an identity shares
# `default`, so binding a cluster-wide role to it would hand the same power to anything anyone deploys
# in this room later. One account, one binding, revocable in one place.
resource "kubernetes_service_account_v1" "hand" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }
}

# ★ CLUSTER-ADMIN BY INTENT (James, 2026-10-19): the hand maintains the cluster alongside him, and
# fingers need to do real work in k8s. The cost is stated once, here: a finger is a model process that
# reads text it did not write, so this is a power that a hostile prompt could borrow. Off by default
# in the module; the room opts in.
resource "kubernetes_cluster_role_binding_v1" "hand" {
  count = var.cluster_admin ? 1 : 0

  metadata {
    name   = "${var.namespace}-${var.name}-cluster-admin"
    labels = local.labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.hand.metadata[0].name
    namespace = var.namespace
  }
}
