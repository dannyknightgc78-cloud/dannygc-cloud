#!/bin/bash
# ============================================================
# DannyGC Hub — Auto Install Script
# Copyright (C) 2026 DannyGC Cloud Services - All Rights Reserved
# ============================================================

set -e

REPO="https://github.com/dannyknightgc78-cloud/dannygc-hub.git"
INSTALL_DIR="/var/www/hub"
DOMAIN="hub.dannygc.cloud"
SSL_CERT="/etc/letsencrypt/live/dannygc.cloud-0001/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/dannygc.cloud-0001/privkey.pem"
NGINX_CONF="/etc/nginx/sites-available/dannygc-hub.conf"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        DannyGC Hub — Auto Installer v1.0             ║"
echo "║        hub.dannygc.cloud                             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 1. Check for git ─────────────────────────────────────────
if ! command -v git &>/dev/null; then
  echo "[INFO] Installing git..."
  sudo apt-get install -y git
fi

# ── 2. Clone or update the repo ──────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "[INFO] Hub already installed — pulling latest updates..."
  cd "$INSTALL_DIR" && sudo git pull origin master
else
  echo "[INFO] Cloning DannyGC Hub to $INSTALL_DIR..."
  sudo git clone "$REPO" "$INSTALL_DIR"
fi

# ── 3. Set permissions ───────────────────────────────────────
sudo chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || true
sudo chmod -R 755 "$INSTALL_DIR"

# ── 4. Write Nginx config ────────────────────────────────────
echo "[INFO] Writing Nginx config for $DOMAIN..."
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate     $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    root $INSTALL_DIR;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";

    # Cache static assets
    location ~* \.(png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

# ── 5. Enable site ───────────────────────────────────────────
if [ ! -f "/etc/nginx/sites-enabled/dannygc-hub.conf" ]; then
  sudo ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/dannygc-hub.conf
  echo "[INFO] Nginx site enabled."
fi

# ── 6. Test and reload Nginx ─────────────────────────────────
echo "[INFO] Testing Nginx config..."
sudo nginx -t

echo "[INFO] Reloading Nginx..."
sudo systemctl reload nginx

# ── 7. Set up auto-update cron (every 6 hours) ───────────────
CRON_JOB="0 */6 * * * cd $INSTALL_DIR && git pull origin master --quiet"
( crontab -l 2>/dev/null | grep -v "dannygc-hub"; echo "$CRON_JOB" ) | crontab -
echo "[INFO] Auto-update cron job set (every 6 hours)."

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅  DannyGC Hub installed successfully!             ║"
echo "║                                                      ║"
echo "║  URL:  https://$DOMAIN          ║"
echo "║  Dir:  $INSTALL_DIR                      ║"
echo "║  Auto-updates: every 6 hours via cron               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
