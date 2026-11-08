#!/usr/bin/env bash
# ==============================================================================
# Script Name: setup-backend.sh
# Purpose: Automated Provisioning for Application / Backend Tier (Node.js & PM2)
# Target OS: Ubuntu 22.04 / 24.04 / 26.04 LTS
# Target Tier: Private Subnet (Backend Tier)
# ==============================================================================

set -euo pipefail

# Configuration Variables
APP_DIR="/home/ubuntu/single-server-3tier-webapp/backend"
GIT_REPO="https://github.com/sarowar-alam/single-server-3tier-webapp.git"
DB_HOST="10.0.3.184"
DB_PORT="5432"
DB_NAME="bmidb"
DB_USER="bmi_user"
DB_PASS="StrongPassword123!"
APP_PORT="5000"

echo "=========================================="
echo " Starting Backend Tier Provisioning...    "
echo "=========================================="

# 1. Update Packages & Install Node.js 20, Git, Build Essentials & PM2
echo "[1/4] Installing Node.js 20, Git, build tools and PM2..."
sudo apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs git build-essential
sudo npm install -g pm2

# 2. Clone Repository & Install Dependencies
echo "[2/4] Cloning repository and installing dependencies..."
cd /home/ubuntu
if [ ! -d "single-server-3tier-webapp" ]; then
  git clone "$GIT_REPO"
fi

cd "$APP_DIR"
npm install

# 3. Configure Environment Variables (.env)
echo "[3/4] Configuring .env file..."
cat << EOF > .env
PORT=${APP_PORT}
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
NODE_ENV=production
FRONTEND_URL=*
EOF

# 4. Start Application with PM2 & Configure Systemd Startup
echo "[4/4] Starting PM2 process and enabling systemd startup..."
pm2 start src/server.js --name bmi-backend || pm2 restart bmi-backend
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -n 1 | sudo bash

# Health check
sleep 2
curl -s http://localhost:${APP_PORT}/health

echo ""
echo "=========================================="
echo " Backend Tier Provisioned Successfully!   "
echo "=========================================="
