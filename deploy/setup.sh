#!/usr/bin/env bash
# Bootstrap script for Donna on a fresh Hostinger KVM2 (Ubuntu 22.04/24.04).
# Run as root: bash deploy/setup.sh
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

DONNA_USER="donna"
DONNA_HOME="/opt/donna"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> System update"
apt-get update -qq && apt-get upgrade -y -qq

echo "==> Install dependencies"
apt-get install -y -qq curl ufw fail2ban unattended-upgrades

# ── Node.js 24 ────────────────────────────────────────────────────────────────
echo "==> Node.js 24"
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt-get install -y -qq nodejs
npm install -g pnpm

# ── Docker CE ─────────────────────────────────────────────────────────────────
echo "==> Docker CE"
curl -fsSL https://get.docker.com | sh 2>/dev/null || true  # already installed is fine

# Block containers from exposing ports to the public interface.
# iptables-persistent conflicts with UFW on Ubuntu 24.04, so we persist this
# rule via a systemd oneshot that runs after Docker starts instead.
cat > /etc/systemd/system/docker-ufw-fix.service <<'UNIT'
[Unit]
Description=Block external access to Docker container ports
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/iptables -I DOCKER-USER -i eth0 ! -s 127.0.0.1 -j DROP

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable docker-ufw-fix --now

# ── Firewall ──────────────────────────────────────────────────────────────────
echo "==> UFW"
apt-get install -y -qq ufw   # reinstall — Docker's get.docker.com script removes it
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   # SSH
ufw --force enable

# ── fail2ban ──────────────────────────────────────────────────────────────────
systemctl enable fail2ban --now

# ── Donna system user ─────────────────────────────────────────────────────────
echo "==> Creating user: $DONNA_USER"
id -u "$DONNA_USER" &>/dev/null || useradd -r -m -d "$DONNA_HOME" -s /bin/bash "$DONNA_USER"
usermod -aG docker "$DONNA_USER"

# ── OpenClaw ──────────────────────────────────────────────────────────────────
echo "==> Installing OpenClaw"
npm install -g openclaw@latest

# ── Config and workspace ──────────────────────────────────────────────────────
echo "==> Deploying config and workspace"
install -d -o "$DONNA_USER" -g "$DONNA_USER" -m 700 "$DONNA_HOME/.openclaw"
install -d -o "$DONNA_USER" -g "$DONNA_USER" -m 755 "$DONNA_HOME/workspace"

# Copy config (symlink not recommended by OpenClaw docs)
install -o "$DONNA_USER" -g "$DONNA_USER" -m 600 \
  "$REPO_DIR/config/openclaw.json5" "$DONNA_HOME/.openclaw/openclaw.json5"

# Copy workspace files (SOUL.md, AGENTS.md)
install -o "$DONNA_USER" -g "$DONNA_USER" -m 644 \
  "$REPO_DIR/workspace/SOUL.md" "$DONNA_HOME/workspace/SOUL.md"
install -o "$DONNA_USER" -g "$DONNA_USER" -m 644 \
  "$REPO_DIR/workspace/AGENTS.md" "$DONNA_HOME/workspace/AGENTS.md"

# ── Secrets ───────────────────────────────────────────────────────────────────
if [[ ! -f "$DONNA_HOME/.env" ]]; then
  echo ""
  echo "  !! $DONNA_HOME/.env not found."
  echo "  !! Copy .env.example to $DONNA_HOME/.env and fill in real values."
  echo "  !! Then re-run: systemctl start donna"
  echo ""
fi

# ── systemd service ───────────────────────────────────────────────────────────
echo "==> Installing systemd service"
OPENCLAW_BIN="$(which openclaw)"

cat > /etc/systemd/system/donna.service <<EOF
[Unit]
Description=Donna — OpenClaw personal assistant
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=$DONNA_USER
Group=$DONNA_USER
WorkingDirectory=$DONNA_HOME
EnvironmentFile=$DONNA_HOME/.env
Environment=OPENCLAW_CONFIG_PATH=$DONNA_HOME/.openclaw/openclaw.json5
Environment=OPENCLAW_HOME=$DONNA_HOME
ExecStart=$OPENCLAW_BIN gateway start
Restart=on-failure
RestartSec=10
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable donna

if [[ -f "$DONNA_HOME/.env" ]]; then
  systemctl start donna
  echo "==> Donna is running. Check: systemctl status donna"
else
  echo "==> Setup complete. Add secrets to $DONNA_HOME/.env, then: systemctl start donna"
fi
