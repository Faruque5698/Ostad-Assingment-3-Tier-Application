#!/usr/bin/env bash
# ==============================================================================
# Script Name: setup-web.sh
# Purpose: Automated Provisioning for Web Tier (React & Nginx Reverse Proxy)
# Target OS: Ubuntu 22.04 / 24.04 / 26.04 LTS
# Target Tier: Public Subnet (Web Tier)
# ==============================================================================

set -euo pipefail

# Configuration Variables
GIT_REPO="https://github.com/sarowar-alam/single-server-3tier-webapp.git"
WEB_ROOT="/var/www/bmi-tracker"
BACKEND_HOST="10.0.2.108"
BACKEND_PORT="5000"

echo "=========================================="
echo " Starting Web Tier Provisioning...        "
echo "=========================================="

# 1. Update Packages & Install Nginx, Git, Node.js 20
echo "[1/4] Installing Nginx, Git and Node.js 20..."
sudo apt-get update -y
sudo apt-get install -y nginx git curl
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Clone Repository & Build React Frontend
echo "[2/4] Cloning repository and building frontend SPA..."
cd ~
if [ ! -d "single-server-3tier-webapp" ]; then
  git clone "$GIT_REPO"
fi

cd single-server-3tier-webapp/frontend
npm install
npm run build

# Deploy assets
sudo mkdir -p "$WEB_ROOT"
sudo cp -r dist/* "$WEB_ROOT/"
sudo chown -R www-data:www-data "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"

# 3. Configure Nginx Reverse Proxy
echo "[3/4] Configuring Nginx virtual host..."
sudo tee /etc/nginx/sites-available/bmi-tracker << EOF
server {
    listen 80 default_server;
    server_name _;

    root ${WEB_ROOT};
    index index.html;

    # SPA Routing
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API Proxy to Backend Server
    location /api/ {
        proxy_pass http://${BACKEND_HOST}:${BACKEND_PORT}/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Health Check Proxy
    location /health {
        proxy_pass http://${BACKEND_HOST}:${BACKEND_PORT}/health;
    }
}
EOF

# 4. Enable Site and Restart Nginx
echo "[4/4] Validating and restarting Nginx..."
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/bmi-tracker /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "=========================================="
echo " Web Tier Provisioned Successfully!       "
echo "=========================================="
