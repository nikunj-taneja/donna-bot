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
.env.example            — Documents required secrets (copy to /opt/donna-bot/.env on VPS)
```

## VPS access

SSH alias `donna` is configured in `~/.ssh/config` (IP: 82.29.166.220, key: `~/.ssh/stay-ssh`).

```bash
ssh donna
```

## Deploying to the VPS

```bash
# 1. SSH into the VPS as root
ssh donna

# 2. Clone the repo (config + workspace are read directly from here)
git clone <repo-url> /opt/donna-bot && cd /opt/donna-bot

# 3. Add secrets
cp .env.example /opt/donna-bot/.env
nano /opt/donna-bot/.env   # fill in real values

# 4. Run bootstrap (installs Node 24, Docker, UFW, openclaw, systemd service)
bash deploy/setup.sh
```

After setup, the service runs as the `donna` system user. Logs: `journalctl -u donna -f`.

## Re-deploying config changes

The VPS reads config and workspace files directly from the git checkout at `/opt/donna-bot`. Push your changes, then:

```bash
ssh donna "cd /opt/donna-bot && git pull && chown -R donna:donna workspace/ config/ && systemctl restart donna"
```

openclaw needs write access to `workspace/` (generates `TOOLS.md` there) and `config/` (last-known-good config backup). Those dirs must stay `donna`-owned — the `chown` above re-applies that after every pull since git runs as root.

## Key architecture decisions

- **Gateway bound to loopback only** — Telegram uses outbound long polling so no public port is needed. UFW blocks all inbound except SSH.
- **DOCKER-USER iptables rule** — prevents Docker from silently punching holes in UFW by inserting a DROP rule before Docker's ACCEPT rules.
- **`donna` system user** — OpenClaw runs unprivileged, added to the `docker` group for sandbox access.
- **Secrets via EnvironmentFile** — `/opt/donna-bot/.env` is never committed; `openclaw.json5` uses `${VAR}` substitution.
- **Session reset at 4am daily** — prevents unbounded context growth and token spend.

## Google Workspace (Gmail, Calendar, Drive)

`gws` (Google's own Workspace CLI) runs as an MCP stdio server inside the gateway. After deploying:

```bash
# Authenticate once as the donna user (file keyring — no daemon needed on VPS)
sudo -u donna GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file gws auth login
# Opens a URL — paste into your browser, grant access, paste the code back
```

Tokens are stored at `/opt/donna-bot/.config/gws/` and refresh automatically.
The gws agent skills are symlinked into `/opt/donna-bot/.openclaw/skills/gws/` by `setup.sh`.

## Secrets needed

| Variable | Where to get it |
|---|---|
| `GOOGLE_API_KEY` | https://aistudio.google.com/apikey |
| `TELEGRAM_BOT_TOKEN` | @BotFather on Telegram → `/newbot` |
| `OPENCLAW_GATEWAY_AUTH_TOKEN` | `openssl rand -hex 32` |

---

## Coding guidelines

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
