#!/bin/sh
# Publishes the pinned oCIS chart to GitHub Container Registry.
#
# ownCloud never publishes this chart as an artifact -- their docs say "we have not yet
# published the oCIS Helm charts" and send you to a git clone. There is no index, no OCI
# artifact and no release asset to install from. This repo publishes it once instead, from
# the commit that pins it, and the module installs what lands here -- the commit below is
# the provenance of the artifact.
#
# Needs a token carrying write:packages: run `helm registry login ghcr.io -u <user>` first.
#
# We publish upstream's chart PLUS ocis-cache-persistence.patch, and say so in the version:
# the artifact is not 0.8.0, it is 0.8.0-jdblack.1. The patch exposes
# OCIS_CACHE_DISABLE_PERSISTENCE (upstream hardcodes it true) so this deployment can keep
# cache streams on the NATS volume instead of losing them whenever the NATS pod is replaced.
set -eu

REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-jdblack/ocis-charts}"

# The upstream version this artifact is built from; CHART_VERSION is what we publish it as.
CHART_COMMIT="${CHART_COMMIT:-fdd5f39b26fe0e7dfeec5697098be226de0eadbd}"
UPSTREAM_VERSION="${UPSTREAM_VERSION:-0.8.0}"
CHART_VERSION="${CHART_VERSION:-0.8.0-jdblack.1}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL "https://codeload.github.com/owncloud/ocis-charts/tar.gz/$CHART_COMMIT" -o "$work/src.tgz"

# Stripped so the path does not depend on how codeload spells the ref.
mkdir -p "$work/src"
tar -xzf "$work/src.tgz" -C "$work/src" --strip-components=1

# The pinned commit and the upstream version have to agree before we touch it, or the patch
# lands on something nobody reviewed.
staged=$(sed -n 's/^version:[[:space:]]*//p' "$work/src/charts/ocis/Chart.yaml")
if [ "$staged" != "$UPSTREAM_VERSION" ]; then
  echo "chart at $CHART_COMMIT is version $staged, expected $UPSTREAM_VERSION" >&2
  exit 1
fi

# Our only divergence from that commit. Kept as a patch so it is readable next to the script
# and fails loudly if the pinned chart stops matching.
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
patch -p1 -d "$work/src" < "$here/ocis-cache-persistence.patch"

# Stamp the version we are actually publishing, so the artifact cannot be mistaken for
# upstream's 0.8.0.
sed "s/^version:.*/version: $CHART_VERSION/" "$work/src/charts/ocis/Chart.yaml" > "$work/Chart.yaml.tmp"
mv "$work/Chart.yaml.tmp" "$work/src/charts/ocis/Chart.yaml"

helm package "$work/src/charts/ocis" -d "$work"
helm push "$work/ocis-$CHART_VERSION.tgz" "oci://$REGISTRY/$NAMESPACE"

echo "published oci://$REGISTRY/$NAMESPACE/ocis:$CHART_VERSION from $CHART_COMMIT"
