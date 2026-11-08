# 3-Tier Application Deployment - Executed Commands

> **Author:** Ashaduzzaman  
> **Email:** [ashaduzzaman5698@gmail.com](mailto:ashaduzzaman5698@gmail.com)  
> **GitHub:** [@Faruque5698](https://github.com/Faruque5698)  

This document records the exact commands executed on the servers for this deployment.

---

## 🌐 Web Server (Frontend & Nginx Reverse Proxy)
- **Instance Name:** `Web-Server`
- **Private IP:** `10.0.1.246`
- **Public IP:** `54.206.70.148`
- **Subnet:** `Public-Subnet-Web` (`10.0.1.0/24`)

### 1. SSH Access from Local Machine
```bash
ssh -i "/c/Users/ASHAD/Desktop/EC2/Web-Server.pem" ubuntu@54.206.70.148
```

### 2. System Update & Dependencies Installation
```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y nginx git curl

# Node.js 20 LTS setup and installation
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### 3. Clone Repository & Build Frontend
```bash
cd ~
git clone https://github.com/sarowar-alam/single-server-3tier-webapp.git
cd single-server-3tier-webapp/frontend

# Install dependencies and build
npm install
npm run build
```

### 4. Deploy Static Assets to Web Root
```bash
sudo mkdir -p /var/www/bmi-tracker
sudo cp -r dist/* /var/www/bmi-tracker/
sudo chown -R www-data:www-data /var/www/bmi-tracker
sudo chmod -R 755 /var/www/bmi-tracker
```

### 5. Configure Nginx Reverse Proxy
```bash
sudo tee /etc/nginx/sites-available/bmi-tracker << 'EOF'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/bmi-tracker;
    index index.html;

    # Frontend Single Page Application Routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API Proxy to Backend Server (Private Subnet)
    location /api/ {
        proxy_pass http://10.0.2.108:5000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health Check Proxy
    location /health {
        proxy_pass http://10.0.2.108:5000/health;
    }
}
EOF
```

### 6. Enable Site & Restart Nginx
```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/bmi-tracker /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## 🗄️ Database Server (PostgreSQL)
- **Instance Name:** `DB-Server`
- **Private IP:** `10.0.3.184`
- **Public IP:** *None (Private)*
- **Subnet:** `Private-Subnet-DB` (`10.0.3.0/24`)
- **Access Method:** AWS Systems Manager (SSM Session Manager)

### 1. Install & Enable PostgreSQL
```bash
sudo su - ubuntu
sudo apt update && sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

### 2. Create Database, User & Schema
```bash
sudo -u postgres psql << 'EOF'
CREATE USER bmi_user WITH PASSWORD 'StrongPassword123!';
CREATE DATABASE bmidb OWNER bmi_user;
GRANT ALL PRIVILEGES ON DATABASE bmidb TO bmi_user;

\c bmidb

GRANT ALL ON SCHEMA public TO bmi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO bmi_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO bmi_user;

CREATE TABLE IF NOT EXISTS measurements (
  id SERIAL PRIMARY KEY,
  weight_kg NUMERIC(5,2) NOT NULL,
  height_cm NUMERIC(5,2) NOT NULL,
  age INTEGER NOT NULL,
  sex VARCHAR(10) NOT NULL,
  activity_level VARCHAR(30),
  bmi NUMERIC(4,1) NOT NULL,
  bmi_category VARCHAR(30),
  bmr INTEGER,
  daily_calories INTEGER,
  measurement_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_measurements_measurement_date ON measurements(measurement_date DESC);
CREATE INDEX IF NOT EXISTS idx_measurements_created_at ON measurements(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_measurements_bmi ON measurements(bmi);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO bmi_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO bmi_user;
\q
EOF
```

### 3. Configure Remote Access for Backend Subnet (`10.0.2.0/24`)
```bash
PG_CONF=$(sudo -u postgres psql -t -P format=unaligned -c 'SHOW config_file')
PG_HBA=$(sudo -u postgres psql -t -P format=unaligned -c 'SHOW hba_file')

# Listen on all network interfaces
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
sudo sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"

# Allow backend subnet (10.0.2.0/24)
echo "host    bmidb           bmi_user        10.0.2.0/24             md5" | sudo tee -a "$PG_HBA"
echo "host    bmidb           bmi_user        10.0.2.0/24             scram-sha-256" | sudo tee -a "$PG_HBA"

# Restart PostgreSQL service
sudo systemctl restart postgresql
sudo systemctl status postgresql --no-pager
```

---

## ⚙️ Application / Backend Server (Node.js & PM2)
- **Instance Name:** `Backend-Server`
- **Private IP:** `10.0.2.108`
- **Public IP:** *None (Private)*
- **Subnet:** `Private-Subnet-Backend` (`10.0.2.0/24`)
- **Access Method:** AWS Systems Manager (SSM Session Manager)

### 1. Switch to Ubuntu User & System Update
```bash
sudo su - ubuntu
sudo apt update -y
```

### 2. Install Node.js 20, Git, Build Essentials & PM2
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs git build-essential
sudo npm install -g pm2
```

### 3. Clone Repository & Install Dependencies
```bash
cd /home/ubuntu
git clone https://github.com/sarowar-alam/single-server-3tier-webapp.git
cd single-server-3tier-webapp/backend
npm install
```

### 4. Configure Environment Variables (.env)
```bash
cat << 'EOF' > .env
PORT=5000
DATABASE_URL=postgresql://bmi_user:StrongPassword123!@10.0.3.184:5432/bmidb
NODE_ENV=production
FRONTEND_URL=*
EOF
```

### 5. Start Application with PM2 & Configure Systemd Startup
```bash
pm2 start src/server.js --name bmi-backend
pm2 save
pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -n 1 | sudo bash
```

### 6. Verify Health Endpoint & Database Connectivity
```bash
curl http://localhost:5000/health
pm2 logs bmi-backend --lines 10 --nostream
curl http://localhost:5000/api/measurements
```

---

## 🎁 Bonus Configurations

### Bonus 1: Load Balancing Between Two App Servers
Executed on `Backend-Server`:
```bash
cd /home/ubuntu/single-server-3tier-webapp/backend
PORT=5001 pm2 start src/server.js --name bmi-backend-2
pm2 save
pm2 status
```

### Bonus 2: Enable HTTPS & Upstream Reverse Proxy on Nginx
Executed on `Web-Server`:
```bash
# 1. Generate Self-Signed SSL Certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key \
  -out /etc/ssl/certs/nginx-selfsigned.crt \
  -subj "/C=BD/ST=Dhaka/L=Dhaka/O=Ostad/OU=DevOps/CN=54.206.70.148"

# 2. Configure Nginx with Upstream Load Balancer, Port 80 Redirect, and Port 443 SSL
sudo tee /etc/nginx/sites-available/bmi-tracker << 'EOF'
# Upstream Load Balancer
upstream backend_cluster {
    server 10.0.2.108:5000;
    server 10.0.2.108:5001;
}

# Redirect HTTP to HTTPS
server {
    listen 80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl default_server;
    server_name _;

    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /var/www/bmi-tracker;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API Load Balanced Proxy
    location /api/ {
        proxy_pass http://backend_cluster/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health Check Load Balanced Proxy
    location /health {
        proxy_pass http://backend_cluster/health;
    }
}
EOF

# 3. Test and Reload Nginx
sudo nginx -t
sudo systemctl restart nginx
```




