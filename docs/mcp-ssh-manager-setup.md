# MCP SSH Manager setup (Codex local)

This runs MCP **locally** and connects to `postgresql.svc.plus` via SSH. No server-side deployment is required.

## Install

```bash
mkdir -p ~/tools
cd ~/tools

git clone https://github.com/bvisible/mcp-ssh-manager.git
cd mcp-ssh-manager
npm install

# Optional CLI helper
cd cli && ./install.sh
cd ..
```

## Configure Codex

```bash
ssh-manager codex setup
```

Edit `~/.codex/ssh-config.toml` and add your server. **Be sure to set your SSH key path**:

```toml
[ssh_servers.postgresql-svc-plus]
host = "postgresql.svc.plus"
user = "root"
key_path = "~/.ssh/id_rsa"   # update to your actual key
port = 22
default_dir = "/root"
description = "postgresql.svc.plus"
```

## Test in Codex

```
"List my SSH servers"
"Execute 'hostname' on postgresql-svc-plus"
"Run 'docker ps' on postgresql-svc-plus"
```
