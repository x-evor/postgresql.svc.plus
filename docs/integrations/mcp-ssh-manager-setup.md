# MCP SSH Manager (Codex local setup)

This guide configures `bvisible/mcp-ssh-manager` on your **local machine** and connects to `postgresql.svc.plus` over SSH. The MCP server runs locally via stdio (no network listener needed on the server).

## Prerequisites (local)

- Node.js 18+
- npm
- Git

## Install (local)

```bash
# Pick a location for the tool
mkdir -p ~/tools
cd ~/tools

# Clone and install

git clone https://github.com/bvisible/mcp-ssh-manager.git
cd mcp-ssh-manager
npm install

# Optional: install the CLI helper
cd cli && ./install.sh
cd ..
```

## Codex integration (recommended)

```bash
# Generate Codex config stubs
ssh-manager codex setup

# If you already have .env servers, migrate them
ssh-manager codex migrate

# Verify integration
ssh-manager codex test
```

## Manual Codex configuration (alternative)

Edit `~/.codex/config.toml` and add:

```toml
[mcp_servers.ssh-manager]
command = "node"
args = ["/absolute/path/to/mcp-ssh-manager/src/index.js"]
env = { SSH_CONFIG_PATH = "/Users/you/.codex/ssh-config.toml" }
startup_timeout_ms = 20000
```

Create or edit `~/.codex/ssh-config.toml`:

```toml
[ssh_servers.postgresql-svc-plus]
host = "postgresql.svc.plus"
user = "root"
key_path = "~/.ssh/id_rsa"   # update to your actual key path
port = 22
default_dir = "/root"
description = "postgresql.svc.plus"
```

## Test in Codex

Try:

```
"List my SSH servers"
"Execute 'hostname' on postgresql-svc-plus"
"Run 'docker ps' on postgresql-svc-plus"
```

## Notes

- This setup runs MCP **locally** and uses SSH to reach `postgresql.svc.plus`.
- If you use a different SSH key or user, update the `ssh-config.toml` entry.
- For full examples, see `examples/codex-ssh-config.example.toml` in the MCP repo.
