locals {
  fqdn        = "${var.name}.${var.domains[var.visibility]}"
  master_host = "master.${local.fqdn}"
  s3_host     = "s3.${var.domains[var.visibility]}"
  lance_host  = "lance.${var.domains[var.visibility]}"

  helm_values = {
    global = {
      enableReplication    = true
      replicationPlacement = "001"
      seaweedfs = {
        image = {
          name = "ghcr.io/jdblack/jblack-seaweedfs"
        }
      }
    }

    image = {
      tag = var.image_tag
    }
    admin = {
      enabled           = true
      grpcPort          = "33646"
      imageOverride     = var.admin_image_override == "" ? null : var.admin_image_override
      extraVolumes      = local.admin_peer_volumes
      extraVolumeMounts = local.admin_peer_mounts
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
      # An accidental-wipe guard, not store-loss protection: the IAM identities live here too.
      podAnnotations = {
        "backup.velero.io/backup-volumes" = "admin-data"
      }
      # The 4.48 chart binds 0.0.0.0 and passes -allowInsecureBind itself; this
      # value is also what its 4.46+ guard checks (extraArgs is not).
      allowInsecureBind = true
      ingress = {
        enabled = false
      }
    }

    master = {
      replicas = 1
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
      podAnnotations = {
        "backup.velero.io/backup-volumes" = "data-kube-storage"
      }
      ingress = {
        enabled = false
      }
    }
    volume = {
      replicas   = var.volume_replicas
      rack       = "0"
      dataCenter = var.data_center
      data = {
        type           = "hostPath"
        storageClass   = ""
        hostPathPrefix = var.host_path_prefix
      }
    }
    filer = {
      replicas = 1
      data = {
        type         = "persistentVolumeClaim"
        size         = "2Gi"
        storageClass = ""
      }
      podAnnotations = {
        "backup.velero.io/backup-volumes" = "data-filer"
      }
    }
    worker = {
      enabled           = true
      replicas          = var.worker_replicas
      jobType           = "all"
      maxConcurrent     = 6
      imageOverride     = var.worker_image_override == "" ? null : var.worker_image_override
      extraVolumes      = local.admin_peer_volumes
      extraVolumeMounts = local.admin_peer_mounts
      data = {
        type           = "emptyDir"
        hostPathPrefix = "/seaweed-worker"
      }

    }
    s3 = {
      enabled     = true
      enableAuth  = true
      domain_name = local.s3_host
      host        = local.s3_host
      # Lance Namespace REST on the s3 gateway; also starts the worker-lance sidecar.
      lancePort = var.lance_enabled ? 9101 : 0
      ingress = {
        enabled = false
      }
    }
  }
}
