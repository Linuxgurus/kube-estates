variable "namespace" { type = string }
variable "velero_namespace" { default = "kube-backup" }

# The backup unit: the PVC this schedule protects. It is the schedule name, so every backup it
# makes is <target>-<timestamp>.
variable "target" { type = string }

# Must match the pod mounting the target PVC: Velero drags the claim in from the pod.
variable "selector" {
  type = map(string)

  validation {
    condition     = length(var.selector) > 0
    error_message = "A target needs a pod selector, otherwise its schedule captures the whole namespace."
  }
}

# Daily cadence is the unit of capture; Velero's garbage collector enforces the TTL, which is the
# retention policy: one backup per day, 7 days deep.
variable "cron" { default = "0 3 * * *" }
variable "ttl" { default = "168h" }

# Offsite copies are made by the ns1 rclone job (pulls the backupstore offsite), so the per-target
# weekly schedule is disabled: an empty BSL name means the weekly resource is not created.
variable "weekly_storage_location" { default = "" }
variable "weekly_cron" { default = "0 4 * * 0" }
variable "weekly_ttl" { default = "720h" }

# ★ COVERAGE IS AN OPT-IN, AND THIS MODULE COULD NOT SAY WHICH. Velero captures a namespace's
# metadata on every schedule; a PVC's BYTES arrive only when the pod carries the annotation
# `backup.velero.io/backup-volumes`, or when the schedule sets `defaultVolumesToFsBackup: true`.
# This module emitted neither, so a target whose pod carries no annotation silently produced
# Completed backups containing zero volume bytes — measured 2026-11-10 on `twine-brain-data`:
# `phase=Completed`, 0 PodVolumeBackups, and a 1.26 GB claim underneath it. A green phase proves
# only that the metadata was copied.
#
# The default is `false` ON PURPOSE: it is the behaviour every existing schedule already has, so
# wiring this field changes no target until a stack asks for it. Turning it on is a cost decision
# (it multiplies the offsite footprint by the size of the volume), so it belongs at the call site,
# not in a module default.
variable "default_volumes_to_fs_backup" {
  description = "Capture the namespace's PVC bytes without per-pod annotations. false preserves absent-behaviour; set true for a target whose pods carry no `backup.velero.io/backup-volumes` annotation."
  type        = bool
  default     = false
}
