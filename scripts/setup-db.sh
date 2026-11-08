#!/usr/bin/env bash
# ==============================================================================
# Script Name: setup-db.sh
# Purpose: Automated Provisioning for Database Tier (PostgreSQL)
# Target OS: Ubuntu 22.04 / 24.04 / 26.04 LTS
# Target Tier: Private Subnet (DB Tier)
# ==============================================================================

set -euo pipefail

# Configuration Variables
DB_NAME="bmidb"
DB_USER="bmi_user"
DB_PASSWORD="StrongPassword123!"
BACKEND_SUBNET_CIDR="10.0.2.0/24"

echo "=========================================="
echo " Starting Database Tier Provisioning..."
echo "=========================================="

# 1. Update Packages & Install PostgreSQL
echo "[1/4] Installing PostgreSQL and Contrib..."
sudo apt-get update -y
sudo apt-get install -y postgresql postgresql-contrib

# 2. Enable and Start PostgreSQL Service
echo "[2/4] Enabling and starting PostgreSQL service..."
sudo systemctl enable postgresql
sudo systemctl start postgresql

# 3. Create Database, User, Table and Indexes
echo "[3/4] Creating database, user, schema and indexes..."
sudo -u postgres psql << EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')\gexec

GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};

\c ${DB_NAME}

GRANT ALL ON SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};

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

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
EOF

# 4. Configure Remote Access for Backend Subnet
echo "[4/4] Configuring network listening and subnet authentication..."
PG_CONF=$(sudo -u postgres psql -t -P format=unaligned -c 'SHOW config_file')
PG_HBA=$(sudo -u postgres psql -t -P format=unaligned -c 'SHOW hba_file')

# Set listen_addresses to '*'
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"
sudo sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"

# Allow backend subnet
if ! grep -q "${BACKEND_SUBNET_CIDR}" "$PG_HBA"; then
  echo "host    ${DB_NAME}           ${DB_USER}        ${BACKEND_SUBNET_CIDR}             scram-sha-256" | sudo tee -a "$PG_HBA"
  echo "host    ${DB_NAME}           ${DB_USER}        ${BACKEND_SUBNET_CIDR}             md5" | sudo tee -a "$PG_HBA"
fi

# Restart PostgreSQL
sudo systemctl restart postgresql
sudo systemctl status postgresql --no-pager

echo "=========================================="
echo " Database Tier Provisioned Successfully! "
echo "=========================================="
