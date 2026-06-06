EXTERNAL_REPO_SSH_KEY=Base64 encoded private ssh key to access config repo
SOPS_AGE_KEY=Base64 encoded age key to decrypt config repo
# For access without devcontainers, this can be added to .claude/settings.local.json
# For access in devcontainers use localhost and kubectl port-forward after the pods are running
GRAFANA_URL=URL to live grafana instance
GRAFANA_SERVICE_ACCOUNT_TOKEN=Used for MCP servers - read only
