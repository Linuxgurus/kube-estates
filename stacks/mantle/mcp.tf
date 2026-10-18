module "mcp" {
  source = "../../modules/mcp"

  # The browser calls the connector for every MCP tool call, so the private gateway is enough
  # -- no WAN exposure for a pod that runs the MCP servers it is handed.
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  auth_token = var.deployment.mcp.auth_token

  # ★ THE OLD STORE IS GONE (2026-10-18), not merely scaled down. On the cutover it was set to 0
  # replicas, which left its HTTPRoute answering `503` at `ellmephant.vn` — indistinguishable from a
  # real outage, and it sent one morning's debugging down a LAN-wall rabbit hole. Now the release,
  # Service, HTTPRoute, TLS secret and PVC are destroyed, so the old name resolves to nothing and
  # fails honestly. The live self is `agent-stet/stet-brain` at `stet.vn.linuxguru.net`.
  #
  # ROLLBACK IS NOW RESTORE, NOT SCALE: the pre-retirement data directory (memory.db + WAL + snapshot,
  # 389 memories) is archived encrypted at
  #   s3://agent-stet-shared/archive/old-chassis/2026-10-18/
  # decrypted with the `stet` secret from ~/.cline/secrets/identities; the README there has the exact
  # openssl line. Verified by downloading, decrypting and reading `bootstrap-self` out of it.
}
