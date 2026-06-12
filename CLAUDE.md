# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Donna is a personal AI assistant built on [OpenClaw](https://openclaw.ai), deployed on a Hostinger KVM2 VPS. It connects via Telegram (long polling — no inbound ports required), uses Google Gemini as the LLM, and sandboxes tool execution in Docker.

## Repository layout

```
config/openclaw.json5   — OpenClaw gateway config (env var placeholders, no secrets)
workspace/SOUL.md       — Donna's persona (loaded by OpenClaw from the agent workspace)
workspace/AGENTS.md     — Donna's operational instructions
deploy/setup.sh         — One-shot bootstrap for a fresh Ubuntu VPS
.env.example            — Documents required secrets (copy to /opt/donna/.env on VPS)
```

## Deploying to the VPS

```bash
# 1. SSH into the VPS as root
ssh root@<vps-ip>

# 2. Clone the repo
git clone <repo-url> /opt/donna-bot && cd /opt/donna-bot

# 3. Add secrets
cp .env.example /opt/donna/.env
nano /opt/donna/.env   # fill in real values

# 4. Run bootstrap (installs Node 24, Docker, UFW, openclaw, systemd service)
bash deploy/setup.sh
```

After setup, the service runs as the `donna` system user. Logs: `journalctl -u donna -f`.

## Re-deploying config changes

```bash
# Copy updated config to VPS
scp config/openclaw.json5 root@<vps-ip>:/opt/donna/.openclaw/openclaw.json5
scp workspace/SOUL.md     root@<vps-ip>:/opt/donna/workspace/SOUL.md
scp workspace/AGENTS.md   root@<vps-ip>:/opt/donna/workspace/AGENTS.md

# Hot reload (most config changes apply without restart)
ssh root@<vps-ip> "systemctl reload donna || systemctl restart donna"
```

## Key architecture decisions

- **Gateway bound to loopback only** — Telegram uses outbound long polling so no public port is needed. UFW blocks all inbound except SSH.
- **DOCKER-USER iptables rule** — prevents Docker from silently punching holes in UFW by inserting a DROP rule before Docker's ACCEPT rules.
- **`donna` system user** — OpenClaw runs unprivileged, added to the `docker` group for sandbox access.
- **Secrets via EnvironmentFile** — `/opt/donna/.env` is never committed; `openclaw.json5` uses `${VAR}` substitution.
- **Session reset at 4am daily** — prevents unbounded context growth and token spend.

## Secrets needed

| Variable | Where to get it |
|---|---|
| `GOOGLE_API_KEY` | https://aistudio.google.com/apikey |
| `TELEGRAM_BOT_TOKEN` | @BotFather on Telegram → `/newbot` |
| `OPENCLAW_GATEWAY_AUTH_TOKEN` | `openssl rand -hex 32` |
