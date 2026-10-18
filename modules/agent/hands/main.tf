locals {
  fqdn       = coalesce(var.hostname, "${var.name}.${var.domain}")
  labels     = { "app.kubernetes.io/name" = var.name, "app.kubernetes.io/part-of" = "agent" }
  health_url = coalesce(one([for u in [var.brain_health_url] : u if u != ""]), replace(var.brain_url, "/mcp", "/health"))

  # ★ MAIL GOES IN-CLUSTER, NEVER VIA THE PUBLIC NAME. The public host resolves to the LAN gateway,
  # which a pod has no route to; `bin/mail`'s own default is that public name.
  brain_root = trimsuffix(var.brain_url, "/mcp")
  mail_me    = var.mail_me == "" ? trimsuffix(var.name, "-hand") : var.mail_me
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

resource "kubernetes_service_v1" "door" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.labels

    port {
      name        = "door"
      port        = 80
      target_port = "door"
    }
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

        security_context {
          fs_group = 1000
        }

        container {
          name  = "door"
          image = "${var.image_repository}:${var.image_tag}"

          # A moving tag + IfNotPresent is a restart that silently runs the old build.
          image_pull_policy = "Always"

          resources {
            requests = { cpu = var.cpu_request, memory = var.memory_request }
            limits   = { memory = var.memory_limit }
          }

          port {
            name           = "door"
            container_port = var.port
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = "door"
            }

            initial_delay_seconds = 3
            period_seconds        = 10
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
            name  = "HANDS_DOOR_PORT"
            value = tostring(var.port)
          }

          # The door spawns hands, which spawn fingers: same rule, no self-updating binary.
          env {
            name  = "CLINE_NO_AUTO_UPDATE"
            value = "1"
          }

          # ★ bin/store and bin/hands read the store from THIS, not from the MCP config. Without it a
          # hand in a new room banks and claims against the old one — which is exactly the split-brain
          # the move exists to avoid.
          env {
            name  = "ELLMEPHANT_URL"
            value = var.brain_url
          }

          env {
            name  = "ELLMEPHANT_HEALTH_URL"
            value = local.health_url
          }

          env {
            name  = "MAIL_URL"
            value = local.brain_root
          }

          env {
            name  = "MAIL_ME"
            value = local.mail_me
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

          env {
            name = "HANDS_DOOR_TOKEN"

            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.door_token_field
              }
            }
          }

          # ★ WHO IS SPEAKING. A finger that cannot prove its name writes as `anonymous` — and since
          # the store's `ELLMEPHANT_LEASERS` names this identity, an anonymous hand cannot take a lease
          # at all (measured 2026-10-17: the deployment had no identity, so PROTECTED writes from the
          # finger were impossible while the image looked fine). BOTH OR NEITHER: the client sends the
          # pair, and the store refuses a name without its proof, so a half-set pair fails loudly.
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

          # ★ MY OWN GIT CREDENTIAL, AND ONLY MINE. A token, not a key on someone's laptop: the push
          # then authenticates as this self, so the audit trail and the commit agree. Absent by default
          # (a room with no forgejo must not fail to start over a missing key).
          dynamic "env" {
            for_each = var.forgejo_token_field == "" ? [] : [var.forgejo_token_field]

            content {
              name = "FORGEJO_TOKEN"

              value_from {
                secret_key_ref {
                  name = var.secret_name
                  key  = env.value
                }
              }
            }
          }

          volume_mount {
            name       = "mcp-config"
            mount_path = "/home/node/.cline/hands/settings/cline_mcp_settings.json"
            sub_path   = "cline_mcp_settings.json"
          }

          # Transcripts, logs and sessions live in RAM: they die with the pod and never touch a volume.
          # ★ THE HOME, OVER THE IMAGE'S COPY. Mounted before the `.tmp` submount below so the baked
          # `bin/` and `dist/` are replaced wholesale by the claim — the image becomes the installer,
          # not the record. `.tmp` stays an emptyDir even here: scratch is supposed to be disposable.
          dynamic "volume_mount" {
            for_each = var.home_claim == "" ? [] : [var.home_claim]

            content {
              name       = "home"
              mount_path = "/home/node/cline-home"
            }
          }

          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/cline-home/.tmp"
          }

          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/.cline/hands/logs"
          }

          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/.cline/hands/sessions"
          }

          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/.cline/hands/db"
          }
        }

        # ★ THE RESIDENT HAND (2026-10-18). Not a bell: one long-lived process that BLOCKS on the
        # mailbox (MCP long-poll) and runs at most ONE finger per letter. It shares this pod with the
        # door because the home claim is RWO — two pods cannot mount it, two containers can — and
        # because a hand that shares the door's lifetime is a hand that restarts with it.
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

          # ★ THE PEN. A hand that does repo work needs its own credential, mounted as an env for now
          # (the narrower file-and-GIT_ASKPASS version is a follow-up: an env is inherited by every
          # child, including a finger's shell).
          dynamic "env" {
            for_each = var.forgejo_token_field == "" ? [] : [var.forgejo_token_field]

            content {
              name = "FORGEJO_TOKEN"

              value_from {
                secret_key_ref {
                  name = var.secret_name
                  key  = env.value
                }
              }
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
