# 3-Tier Application Deployment on Custom AWS VPC (Nginx Only)

> **Author:** Ashaduzzaman  
> **Email:** [ashaduzzaman5698@gmail.com](mailto:ashaduzzaman5698@gmail.com)  
> **GitHub:** [@Faruque5698](https://github.com/Faruque5698)  

## 📌 Project Overview
This project involves deploying a secure **3-Tier Web Application** on Amazon Web Services (AWS) within a custom Virtual Private Cloud (VPC):
- **Web Tier (Public Subnet):** EC2 instance running Nginx acting as the sole public entry point, serving the frontend and reverse-proxying API traffic.
- **Application Tier (Private Subnet):** EC2 instance hosting the backend API service (configured with systemd to auto-restart on reboot).
- **Database Tier (Private Subnet):** EC2 instance running MySQL/PostgreSQL, strictly isolated and accessible only from the Application Tier.

---

## 🏛️ Architecture Diagram

![AWS 3-Tier Web Application Architecture](Screenshot/architecture.svg)

<details>
<summary><b>Click to expand Mermaid Architecture Source Code</b></summary>

```mermaid
flowchart TD
    subgraph Internet ["Public Internet"]
        Users["Users / Web Browsers"]
    end

    subgraph AWS ["AWS Cloud (Region: ap-southeast-2)"]
        subgraph VPC ["Custom VPC: Assignment-VPC (10.0.0.0/16)"]
            
            IGW["Internet Gateway: Assignment-IGW"]
            
            subgraph PublicSubnet ["Public Subnet: Public-Subnet-Web (10.0.1.0/24)"]
                WebServer["Web-Server (10.0.1.246)<br/>Public IP: 54.206.70.148<br/>Nginx + React SPA<br/>SG: Web-SG (Ports 80, 443, 22)"]
                NAT["NAT Gateway: Assignment-NAT<br/>Elastic IP: 13.238.213.222"]
            end
            
            subgraph PrivateAppSubnet ["Private Subnet: Private-Subnet-Backend (10.0.2.0/24)"]
                BackendServer["Backend-Server (10.0.2.108)<br/>Node.js 20 & PM2 REST API<br/>Upstream Ports: 5000 & 5001<br/>SG: Backend-SG (Ports 5000-5001)"]
            end
            
            subgraph PrivateDBSubnet ["Private Subnet: Private-Subnet-DB (10.0.3.0/24)"]
                DBServer["DB-Server (10.0.3.184)<br/>PostgreSQL 18 RDBMS (bmidb)<br/>SG: DB-SG (Port 5432)"]
            end
            
        end

        SSM["AWS Systems Manager (SSM)<br/>IAM Role: EC2-SSM-Role"]
    end

    Users -->|"HTTPS: 443 / HTTP: 80"| IGW
    IGW --> WebServer
    WebServer -->|"Upstream Load Balanced :5000, 5001"| BackendServer
    BackendServer -->|"Database Query :5432"| DBServer

    BackendServer -.->|"Outbound Updates"| NAT
    DBServer -.->|"Outbound Updates"| NAT
    NAT -.-> IGW

    SSM -.->|"Session Manager Access"| BackendServer
    SSM -.->|"Session Manager Access"| DBServer
```
</details>

---

## 🚀 Implementation Progress

### Step 1: Create Custom VPC
A custom Virtual Private Cloud (VPC) was provisioned to serve as the isolated networking boundary for the 3-tier architecture.

- **VPC Name:** `Assignment-VPC`
- **IPv4 CIDR Block:** `10.0.0.0/16` (providing 65,536 private IP addresses)
- **Tenancy:** Default
- **VPC ID:** `vpc-0b35b80212d35165e`

#### 1. VPC Configuration
Configuring VPC settings with IPv4 CIDR `10.0.0.0/16` and Name tag `Assignment-VPC`.

![VPC Configuration](Screenshot/VPC/1.png)

#### 2. VPC Successfully Created
The `Assignment-VPC` is provisioned and in an `Available` state with its default route table generated.

![VPC Created Details](Screenshot/VPC/2.png)

---

### Step 2: Subnet Configuration
Three dedicated subnets were created within `Assignment-VPC` across the availability zone (`ap-southeast-2a`) to segregate each tier of the application:

| Subnet Name | Tier / Type | CIDR Block | Availability Zone | Subnet ID | Purpose |
|---|---|---|---|---|---|
| `Public-Subnet-Web` | Web (Public) | `10.0.1.0/24` | `ap-southeast-2a` | `subnet-059e4dd2ce0b03f9b` | Nginx reverse proxy & frontend host |
| `Private-Subnet-Backend` | App (Private) | `10.0.2.0/24` | `ap-southeast-2a` | `subnet-09d061213b44a6480` | Backend API service |
| `Private-Subnet-DB` | Database (Private) | `10.0.3.0/24` | `ap-southeast-2a` | `subnet-0087410ce4aa558e8` | PostgreSQL Database instance |

#### 1. Creating Subnets
Configuring the 3 subnets with their respective CIDR blocks under `Assignment-VPC`.

![Create Subnets](Screenshot/Subnets/1.png)

#### 2. Subnets Created Successfully
All three subnets are successfully created and in the `Available` state.

![Subnets Created Details](Screenshot/Subnets/2.png)

---

### Step 3: Enable Auto-Assign Public IPv4 Address
To ensure EC2 instances launched in the public subnet (Web tier) receive a publicly accessible IP address automatically, auto-assignment of public IPv4 addresses was enabled for `Public-Subnet-Web`:

- **Subnet Name:** `Public-Subnet-Web`
- **Subnet ID:** `subnet-059e4dd2ce0b03f9b`
- **Setting Enabled:** `Enable auto-assign public IPv4 address`

#### 1. Enabling Auto-Assign Public IP
Editing subnet settings to enable automatic public IPv4 address assignment for instances launched in the web tier.

![Enable Auto-assign Public IP](Screenshot/Public-IP-assign/1.png)

#### 2. Settings Confirmed
The `Auto-assign public IPv4 address` status updated to `Yes`.

![Auto-assign Public IP Verified](Screenshot/Public-IP-assign/2.png)

---

### Step 4: Create and Attach Internet Gateway (IGW)
An Internet Gateway was provisioned and attached to `Assignment-VPC` to provide internet access to the public subnet resources (Nginx reverse proxy / Web tier).

- **Internet Gateway Name:** `Assignment-IGW`
- **Internet Gateway ID:** `igw-01cef797b7ac6d937`
- **Attached VPC:** `vpc-0b35b80212d35165e` (`Assignment-VPC`)
- **State:** `Attached`

#### 1. Creating Internet Gateway
Configuring Name tag `Assignment-IGW` to create the Internet Gateway.

![Create Internet Gateway](Screenshot/IGW/1.png)

#### 2. Internet Gateway Created (Detached)
The gateway `igw-01cef797b7ac6d937` is provisioned and ready to be attached to the VPC.

![Internet Gateway Created](Screenshot/IGW/2.png)

#### 3. Attaching to Custom VPC
Selecting `Assignment-VPC` (`vpc-0b35b80212d35165e`) to attach the Internet Gateway.

![Attach IGW to VPC](Screenshot/IGW/3.png)

#### 4. Internet Gateway Attached Successfully
The Internet Gateway is now attached and active (`Attached` state) within `Assignment-VPC`.

![IGW Attached Successfully](Screenshot/IGW/4.png)

---

### Step 5: Provision NAT Gateway (for Private Subnets)
A managed NAT Gateway with an allocated Elastic IP was created inside the public subnet (`Public-Subnet-Web`). This enables instances in private subnets (`Private-Subnet-Backend` and `Private-Subnet-DB`) to make outbound internet connections (e.g., system updates, npm package installations) while keeping them completely shielded from inbound internet traffic.

- **NAT Gateway Name:** `Assignment-NAT`
- **NAT Gateway ID:** `nat-062ff408f7e151f75`
- **Subnet Placement:** `Public-Subnet-Web` (`subnet-059e4dd2ce0b03f9b`)
- **Connectivity Type:** `Public`
- **Allocated Elastic IP:** `13.238.213.222` (`eipalloc-03d150f3282f04631`)
- **Primary Private IP:** `10.0.1.118`

#### 1. Configuring NAT Gateway with Elastic IP
Allocating an Elastic IP (`13.238.213.222`) and placing the NAT Gateway into `Public-Subnet-Web`.

![Create NAT Gateway](Screenshot/NAT/1.png)

#### 2. NAT Gateway Provisioning Details
NAT Gateway `nat-062ff408f7e151f75` created under `Assignment-VPC` and provisioning.

![NAT Gateway Created](Screenshot/NAT/2.png)

---

### Step 6: Route Tables Configuration
Two custom route tables were provisioned within `Assignment-VPC` to separate public and private routing:
- **Public Route Table (`Public-RT`):** Will route internet-bound traffic (`0.0.0.0/0`) via the Internet Gateway (`Assignment-IGW`) and associate with `Public-Subnet-Web`.
- **Private Route Table (`Private-RT`):** Will route outbound traffic (`0.0.0.0/0`) via the NAT Gateway (`Assignment-NAT`) and associate with the private subnets.

| Route Table Name | Route Table ID | VPC | Type | Configured Route (`0.0.0.0/0`) | Purpose |
|---|---|---|---|---|---|
| `Public-RT` | `rtb-0c65f18d22c29f61c` | `Assignment-VPC` | Public | Target: `igw-01cef797b7ac6d937` (`Assignment-IGW`) | Routes public internet traffic directly via Internet Gateway |
| `Private-RT` | `rtb-07473dd09586c8c3c` | `Assignment-VPC` | Private | Target: `nat-062ff408f7e151f75` (`Assignment-NAT`) | Routes outbound internet traffic via NAT Gateway |

#### 1. Creating Public Route Table
Configuring Name tag `Public-RT` and associating it with `Assignment-VPC`.

![Create Public Route Table](Screenshot/Route-Table/1.png)

#### 2. Public Route Table Created
`Public-RT` (`rtb-0c65f18d22c29f61c`) is created with default local route (`10.0.0.0/16`).

![Public Route Table Created](Screenshot/Route-Table/2.png)

#### 3. Creating Private Route Table
Configuring Name tag `Private-RT` and associating it with `Assignment-VPC`.

![Create Private Route Table](Screenshot/Route-Table/3.png)

#### 4. Private Route Table Created
`Private-RT` (`rtb-07473dd09586c8c3c`) is created with default local route (`10.0.0.0/16`).

![Private Route Table Created](Screenshot/Route-Table/4.png)

#### 5. Route Tables Overview
Summary view showing both `Public-RT` and `Private-RT` provisioned for `Assignment-VPC`.

![Route Tables Overview](Screenshot/Route-Table/5.png)

#### 6. Adding Internet Gateway Route to Public-RT
Editing routes for `Public-RT` (`rtb-0c65f18d22c29f61c`) by adding destination `0.0.0.0/0` with target pointing to Internet Gateway `Assignment-IGW` (`igw-01cef797b7ac6d937`).

![Public Route Table Add Route](Screenshot/Route-Table/6.png)

#### 7. Public Route Table Routes Updated
`Public-RT` routes successfully updated with internet-bound traffic routed through the Internet Gateway.

![Public Route Table Routes Updated](Screenshot/Route-Table/7.png)

#### 8. Adding NAT Gateway Route to Private-RT
Editing routes for `Private-RT` (`rtb-07473dd09586c8c3c`) by adding destination `0.0.0.0/0` with target pointing to NAT Gateway `Assignment-NAT` (`nat-062ff408f7e151f75`).

![Private Route Table Add Route](Screenshot/Route-Table/8.png)

#### 9. Private Route Table Routes Updated
`Private-RT` routes successfully updated with outbound traffic routed through the NAT Gateway.

![Private Route Table Routes Updated](Screenshot/Route-Table/9.png)

#### 10. Associating Public Subnet with Public-RT
Explicitly associating `Public-Subnet-Web` (`subnet-059e4dd2ce0b03f9b`) with `Public-RT` (`rtb-0c65f18d22c29f61c`).

![Public Subnet Association](Screenshot/Route-Table/10.png)

#### 11. Associating Private Subnets with Private-RT
Explicitly associating `Private-Subnet-DB` (`subnet-0087410ce4aa558e8`) and `Private-Subnet-Backend` (`subnet-09d061213b44a6480`) with `Private-RT` (`rtb-07473dd09586c8c3c`) to route outbound traffic through the NAT Gateway.

![Private Subnets Association](Screenshot/Route-Table/11.png)


---

### Step 7: Security Groups Configuration (Tier-to-Tier Isolation)
To enforce strict defense-in-depth isolation across the 3-tier architecture, dedicated Security Groups were created under `Assignment-VPC`. Traffic flow follows the principle of least privilege:
`Internet` ➔ `Web-SG` (Ports 80, 443, 22) ➔ `Backend-SG` (Port 5000) ➔ `DB-SG` (Port 3306).

| Security Group Name | Security Group ID | Tier | Inbound Port | Allowed Source | Purpose |
|---|---|---|---|---|---|
| `Web-SG` | `sg-0ed1c1b8d2dbd208f` | Web (Public) | 80 (HTTP), 443 (HTTPS), 22 (SSH) | `0.0.0.0/0` (Internet) | Allows public web traffic to Nginx reverse proxy and administrative SSH |
| `Backend-SG` | `sg-060cdbf41d84e9e24` | Application (Private) | 5000 (Custom TCP) | `sg-0ed1c1b8d2dbd208f` (`Web-SG`) | Restricts backend API access strictly to Web tier |
| `DB-SG` | `sg-085819857ec568444` | Database (Private) | 3306 (MySQL/Aurora) | `sg-060cdbf41d84e9e24` (`Backend-SG`) | Restricts database access strictly to Backend tier |

#### 1. Configuring Web-SG (HTTP, HTTPS, SSH)
`Web-SG` (`sg-0ed1c1b8d2dbd208f`) configured with inbound rules for HTTP (port 80), HTTPS (port 443), and SSH (port 22) from anywhere (`0.0.0.0/0`).

![Configure Web-SG](Screenshot/Security-Group/1.png)

#### 2. Configuring Backend-SG
Creating `Backend-SG` allowing inbound traffic on application port `5000` exclusively sourced from `Web-SG` (`sg-0ed1c1b8d2dbd208f`).

![Configure Backend-SG](Screenshot/Security-Group/2.png)

#### 3. Backend-SG Created Successfully
`Backend-SG` (`sg-060cdbf41d84e9e24`) provisioned and verified with tier-to-tier reference rule.

![Backend-SG Created](Screenshot/Security-Group/3.png)

#### 4. Configuring DB-SG
Creating `DB-SG` allowing inbound database traffic on port `3306` exclusively sourced from `Backend-SG` (`sg-060cdbf41d84e9e24`).

![Configure DB-SG](Screenshot/Security-Group/4.png)

#### 5. DB-SG Created Successfully
`DB-SG` (`sg-085819857ec568444`) provisioned and verified with database isolation rule.

![DB-SG Created](Screenshot/Security-Group/5.png)

#### 6. Security Groups Overview
Consolidated view showing all three dedicated security groups (`Web-SG`, `Backend-SG`, `DB-SG`) provisioned under `Assignment-VPC`.

![Security Groups Overview](Screenshot/Security-Group/6.png)

#### 7. Backend-SG Inbound Rule Verified
Inbound rule configuration for `Backend-SG` (`sg-060cdbf41d84e9e24`) allowing application port `5000` traffic exclusively sourced from `Web-SG` (`sg-0ed1c1b8d2dbd208f`).

![Backend-SG Inbound Rule](Screenshot/Security-Group/7.png)

---

### Step 8: IAM Role Configuration for AWS Systems Manager (SSM)
To securely manage and access EC2 instances—specifically the private backend and database instances—without opening SSH port 22 or deploying a Bastion host, an IAM instance profile was created with AWS Systems Manager (SSM) Session Manager permissions:

- **Role Name:** `EC2-SSM-Role`
- **Trusted Entity:** AWS Service (`EC2`)
- **Attached Policy:** `AmazonSSMManagedInstanceCore`

#### 1. Selecting Trusted Entity
Selecting AWS Service `EC2` as the trusted entity for the IAM role.

![Select Trusted Entity](Screenshot/SSM/Role/1.png)

#### 2. Attaching SSM Policy
Attaching the AWS managed permission policy `AmazonSSMManagedInstanceCore`.

![Attach SSM Policy](Screenshot/SSM/Role/2.png)

#### 3. Reviewing and Creating Role
Reviewing role configuration with trust policy, permissions, and Name tag `EC2-SSM-Role`.

![Review IAM Role](Screenshot/SSM/Role/3.png)

#### 4. IAM Role Created Successfully
The `EC2-SSM-Role` is created and available for instance attachment.

![IAM Role Created](Screenshot/SSM/Role/4.png)

---

### Step 9: EC2 Instances Provisioning (3-Tier Infrastructure)
Three dedicated EC2 instances were provisioned across the three respective subnets, strictly enforcing network segmentation and security group attachments:

| Instance Name | Instance ID | Subnet / Tier | Private IPv4 | Public IPv4 | Attached Security Group | Instance Type | OS / AMI |
|---|---|---|---|---|---|---|---|
| `Web-Server` | `i-0d609e22897cdf3a8` | `Public-Subnet-Web` (`10.0.1.0/24`) | `10.0.1.246` | `54.206.70.148` | `Web-SG` (`sg-0ed1c1b8d2dbd208f`) | `t3.micro` | Ubuntu Server 26.04 LTS |
| `Backend-Server` | `i-0189f7c85e2df1228` | `Private-Subnet-Backend` (`10.0.2.0/24`) | `10.0.2.108` | *None (Private)* | `Backend-SG` (`sg-060cdbf41d84e9e24`) | `t3.micro` | Ubuntu Server 26.04 LTS |
| `DB-Server` | `i-0a0b0474311783eb7` | `Private-Subnet-DB` (`10.0.3.0/24`) | `10.0.3.184` | *None (Private)* | `DB-SG` (`sg-085819857ec568444`) | `t3.micro` | Ubuntu Server 26.04 LTS |

#### 1. Web-Server Provisioned (Public Web Tier)
`Web-Server` launched into `Public-Subnet-Web` with auto-assigned Public IPv4 (`54.206.70.148`) and Private IPv4 (`10.0.1.246`).

![Web-Server Details](Screenshot/Ec2/1.png)

#### 2. Backend-Server Provisioned (Private App Tier)
`Backend-Server` launched into `Private-Subnet-Backend` with Private IPv4 (`10.0.2.108`) and no public IP exposure.

![Backend-Server Details](Screenshot/Ec2/2.png)

#### 3. Launching DB-Server (Private DB Tier)
Configuring `DB-Server` with Ubuntu OS, `t3.micro`, and `DB-SG` security group.

![Launch DB-Server](Screenshot/Ec2/3.png)

#### 4. DB-Server Provisioned Successfully
`DB-Server` active in `Private-Subnet-DB` with Private IPv4 (`10.0.3.184`) and zero public IP exposure.

![DB-Server Details](Screenshot/Ec2/4.png)

#### 5. All 3 Instances Running Overview
Consolidated EC2 console showing all three tiers (`Web-Server`, `Backend-Server`, `DB-Server`) running healthy in `ap-southeast-2a`.

![EC2 Instances Running Overview](Screenshot/Ec2/5.png)

#### 6. Attaching EC2-SSM-Role to DB-Server
Configured and attached `EC2-SSM-Role` to `DB-Server` (`i-0a0b0474311783eb7`) to grant Systems Manager permissions for secure access.

![DB-Server IAM Role](Screenshot/Ec2/6.png)

#### 7. Attaching EC2-SSM-Role to Backend-Server
Configured and attached `EC2-SSM-Role` to `Backend-Server` (`i-0189f7c85e2df1228`) to enable Systems Manager Session Manager access without public SSH.

![Backend-Server IAM Role](Screenshot/Ec2/7.png)

---

### Step 10: Database Tier Setup (PostgreSQL on DB-Server)
The database tier was provisioned on `DB-Server` (`10.0.3.184`) within `Private-Subnet-DB`. To maintain maximum security, the instance has no public IP and was managed securely through **AWS Systems Manager (SSM) Session Manager**.

- **Database Engine:** PostgreSQL 18
- **Database Name:** `bmidb`
- **Database User:** `bmi_user`
- **Listening Port:** `5432`
- **Authorized Client Subnet:** `10.0.2.0/24` (`Private-Subnet-Backend`)

#### Key Actions Executed:
1. **Installed & Enabled PostgreSQL Service:**
   ```bash
   sudo apt update && sudo apt install -y postgresql postgresql-contrib
   sudo systemctl enable postgresql
   sudo systemctl start postgresql
   ```
2. **Created Application Database, User & Schema:**
   - Provisioned database `bmidb` owned by user `bmi_user`.
   - Created the `measurements` table storing `weight_kg`, `height_cm`, `age`, `sex`, `activity_level`, `bmi`, `bmi_category`, `bmr`, `daily_calories`, `measurement_date`, and `created_at`.
   - Created B-tree performance indexes on `measurement_date`, `created_at`, and `bmi`.
3. **Configured Network Listening & Remote Access:**
   - In `postgresql.conf`: Updated `listen_addresses = '*'` to listen across all interfaces.
   - In `pg_hba.conf`: Added access rules allowing connections to `bmidb` for `bmi_user` exclusively from the application tier subnet (`10.0.2.0/24`) using `scram-sha-256` and `md5`.
   - Restarted PostgreSQL service and verified status `active (running)`.

---

### Step 11: Application Tier Deployment (Node.js & PM2 on Backend-Server)
The application tier was deployed on `Backend-Server` (`10.0.2.108`) within `Private-Subnet-Backend`. It is accessible solely through SSM Session Manager for administration and via internal VPC traffic on port `5000` from `Web-Server`.

- **Runtime:** Node.js 20 LTS
- **Process Manager:** PM2 (configured with systemd auto-start)
- **Application Port:** `5000` (Custom TCP)
- **Database Connection:** `postgresql://bmi_user:StrongPassword123!@10.0.3.184:5432/bmidb`

#### Key Actions Executed:
1. **Installed Node.js 20, Git, Build Essentials & PM2:**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt install -y nodejs git build-essential
   sudo npm install -g pm2
   ```
2. **Deployed Codebase & Installed Dependencies:**
   - Cloned repository to `/home/ubuntu/single-server-3tier-webapp`.
   - Installed production dependencies (`express`, `pg`, `cors`, `dotenv`, `body-parser`) in `backend/`.
3. **Configured Environment (.env):**
   ```env
   PORT=5000
   DATABASE_URL=postgresql://bmi_user:StrongPassword123!@10.0.3.184:5432/bmidb
   NODE_ENV=production
   FRONTEND_URL=*
   ```
4. **Daemonized with PM2 & Persistent Startup:**
   - Started server with PM2: `pm2 start src/server.js --name bmi-backend`.
   - Saved process dump: `pm2 save`.
   - Enabled systemd service: `pm2 startup systemd -u ubuntu --hp /home/ubuntu`.
5. **Connectivity & Health Verification:**
   - Health check: `curl http://localhost:5000/health` ➔ `{"status":"ok","environment":"production"}`
   - Database Pool Query verified: `✅ Database connected successfully at: 2026-11-08T17:05:06.276Z`
   - Data query test: `curl http://localhost:5000/api/measurements` ➔ `{"rows":[]}`

---

### Step 12: Web Tier Deployment (React & Nginx Reverse Proxy on Web-Server)
The web tier was deployed on `Web-Server` (`10.0.1.246`, Public IP `54.206.70.148`) in `Public-Subnet-Web`. It serves as the sole public-facing reverse proxy and static asset server.

- **Web Server:** Nginx
- **Frontend Framework:** React 18 / Vite SPA
- **Public Port:** `80` (HTTP)

#### Key Actions Executed:
1. **Built Frontend Application:**
   - Cloned codebase and compiled optimized static production bundle (`npm run build`).
   - Deployed bundle to `/var/www/bmi-tracker` and granted ownership to `www-data:www-data`.
2. **Configured Nginx Reverse Proxy (`/etc/nginx/sites-available/bmi-tracker`):**
   - Served React Single Page Application on root `/` with HTML5 push-state routing (`try_files $uri $uri/ /index.html`).
   - Reverse-proxied all `/api/` traffic to the private application tier:
     ```nginx
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
     ```
   - Reverse-proxied `/health` to `http://10.0.2.108:5000/health`.
3. **Enabled Site & Verified:**
   - Created symlink in `/etc/nginx/sites-enabled/`.
   - Ran `nginx -t` (syntax ok) and restarted Nginx service.

---

### Step 13: End-to-End Application Verification & Live Testing
The entire 3-tier application was verified live by accessing the public IP `http://54.206.70.148` from a web browser.

#### Data Flow Across Tiers:
1. **Client Browser** ➔ Sends HTTP GET/POST to Public IP `54.206.70.148:80` (`Web-Server`).
2. **Web Tier (Nginx)** ➔ Serves React SPA static assets; forwards API calls (`/api/measurements`) over private subnet to `10.0.2.108:5000` (`Backend-Server`).
3. **Application Tier (Node.js/Express)** ➔ Validates input, calculates BMI, BMR, and daily calories; executes parameterized SQL query against `10.0.3.184:5432` (`DB-Server`).
4. **Database Tier (PostgreSQL)** ➔ Persists health record into `measurements` table in `bmidb` and returns created row.
5. **Response Propagation** ➔ Response flows back through Backend ➔ Nginx ➔ Client Browser, dynamically rendering real-time results and updating the history log.

#### 1. Live BMI & Health Tracker Application (Production View)
The BMI & Health Tracker web application running live in production, displaying calculated BMI categories, metabolic metrics, and database-persisted health records.

![Live BMI Tracker Application](Screenshot/Production/image.png)

#### 2. Full Application Interface & Records History
Comprehensive view of the responsive UI demonstrating real-time health data persistence and complete end-to-end integration across Web, Application, and Database tiers.

![Full Production Application View](Screenshot/Production/full.png)

---

### 🛡️ Architecture & Security Summary

| Architecture Layer | Component | Subnet | Private IP | Public IP | Security Group | Inbound Rules | Outbound |
|---|---|---|---|---|---|---|---|
| **Web Tier** | Nginx Reverse Proxy & React SPA | `Public-Subnet-Web` (`10.0.1.0/24`) | `10.0.1.246` | `54.206.70.148` | `Web-SG` (`sg-0ed1c1b8d2dbd208f`) | Port 80 (HTTP), 443 (HTTPS), 22 (SSH) from `0.0.0.0/0` | All Traffic via Internet Gateway (`Assignment-IGW`) |
| **Application Tier** | Node.js 20 & PM2 REST API | `Private-Subnet-Backend` (`10.0.2.0/24`) | `10.0.2.108` | *None* | `Backend-SG` (`sg-060cdbf41d84e9e24`) | Port 5000 exclusively from `Web-SG` (`sg-0ed1c1b8d2dbd208f`) | All Traffic via NAT Gateway (`Assignment-NAT`) |
| **Database Tier** | PostgreSQL 18 RDBMS | `Private-Subnet-DB` (`10.0.3.0/24`) | `10.0.3.184` | *None* | `DB-SG` (`sg-085819857ec568444`) | Port 5432 exclusively from `Backend-SG` (`sg-060cdbf41d84e9e24`) | All Traffic via NAT Gateway (`Assignment-NAT`) |
| **Administrative Access** | AWS Systems Manager (SSM) | VPC-wide | N/A | N/A | IAM Role: `EC2-SSM-Role` | Zero inbound management ports required (Session Manager over TLS 443 via NAT) | Outbound HTTPS to SSM endpoints |

---

## 📝 Challenges Faced & Solutions (Troubleshooting Note)

During the deployment of this 3-tier architecture, several infrastructure, networking, and configuration challenges were encountered and systematically resolved:

### 1. Private Subnets Outbound Internet Routing (NAT Association)
- **Problem:** Instances in the private subnets (`Backend-Server` and `DB-Server`) could not download packages via `apt`, clone git repositories, or register with AWS Systems Manager, resulting in `dial tcp 3.27.177.60:443: i/o timeout`.
- **Root Cause:** Although `Private-RT` had a valid `0.0.0.0/0` route pointing to `Assignment-NAT`, `Private-Subnet-Backend` and `Private-Subnet-DB` were not explicitly associated with `Private-RT` and remained on the main VPC route table (which had no internet gateway).
- **Solution:** Explicitly associated both private subnets with `Private-RT` (`rtb-07473dd09586c8c3c`) in the VPC Console, immediately restoring outbound internet connectivity via the NAT Gateway.

### 2. AWS Systems Manager (SSM) Session Manager Access
- **Problem:** Unable to access private instances through AWS Systems Manager Session Manager (the Session Manager connection option failed or remained grayed out).
- **Root Cause:** The EC2 instances lacked an IAM Instance Profile granting the EC2 SSM agent permission to authenticate with AWS Systems Manager service endpoints.
- **Solution:** Created an IAM Role named `EC2-SSM-Role` with the AWS managed policy `AmazonSSMManagedInstanceCore`, attached it as an IAM Instance Profile to both `DB-Server` and `Backend-Server`, and rebooted the instances. This enabled secure, browser-based CLI access without requiring a public IP or open SSH port 22.

### 3. Database Engine Alignment (MySQL vs PostgreSQL)
- **Problem:** Generic assignment templates referenced MySQL (Port 3306), but the assigned codebase (`single-server-3tier-webapp`) relies on Node.js with the `pg` client library and Postgres-specific syntax (`$1, $2`, `SERIAL PRIMARY KEY`, `RETURNING *`).
- **Root Cause:** Deploying MySQL would cause runtime query and connection errors in the backend application.
- **Solution:** Provisioned PostgreSQL 18 on `DB-Server`, created user `bmi_user`, database `bmidb`, and the `measurements` table with performance indexes, ensuring native compatibility with the application codebase.

### 4. PostgreSQL Remote Listening & Client Authentication
- **Problem:** Backend server could not connect to PostgreSQL on `DB-Server` (`10.0.3.184:5432`), rejecting remote network connections.
- **Root Cause:** By default, PostgreSQL on Ubuntu only listens on `localhost` (127.0.0.1) and enforces local peer authentication, denying remote private IP subnets.
- **Solution:** Modified `postgresql.conf` to set `listen_addresses = '*'` and updated `pg_hba.conf` by adding host authentication rules for `bmidb` and `bmi_user` from the backend subnet CIDR (`10.0.2.0/24`) using `scram-sha-256` and `md5`, then restarted the service.

### 5. Database Security Group Port Alignment
- **Problem:** `DB-SG` was originally configured with inbound port `3306` (MySQL) from `Backend-SG`, blocking traffic to PostgreSQL port `5432`.
- **Root Cause:** Legacy port definition from the initial template.
- **Solution:** Updated `DB-SG` (`sg-085819857ec568444`) inbound rules to allow port `5432` (PostgreSQL) strictly sourced from `Backend-SG` (`sg-060cdbf41d84e9e24`).

### 6. Application Port Alignment & Process Management
- **Problem:** The backend repository defaulted to `PORT=3000` in `.env.example`, whereas Nginx and `Backend-SG` were configured to communicate over port `5000`.
- **Root Cause:** Port mismatch between default code environment and cloud infrastructure security rules.
- **Solution:** Defined `PORT=5000` in `/home/ubuntu/single-server-3tier-webapp/backend/.env`, deployed the backend with PM2 (`pm2 start src/server.js --name bmi-backend`), and configured systemd persistence (`pm2 startup systemd` and `pm2 save`) to ensure automatic restart on instance reboots.

---

## 🎁 Bonus Tasks Implementation (+10)

All three bonus requirements were implemented and verified across the architecture:

### Bonus 1: Load Balancing Between Two Application Servers Using Nginx
To ensure high availability and distributed workload across the application tier, Nginx was configured with an upstream load balancing cluster:
- **Upstream Cluster Configuration:** Defined `backend_cluster` containing two independent backend application instances running on port `5000` and `5001`.
  ```nginx
  upstream backend_cluster {
      server 10.0.2.108:5000;
      server 10.0.2.108:5001;
  }
  ```
- **Security Group Update:** Updated `Backend-SG` (`sg-060cdbf41d84e9e24`) inbound rule to allow port range `5000-5001` exclusively from `Web-SG` (`sg-0ed1c1b8d2dbd208f`).
- **Load Balancing Algorithm:** Standard Round-Robin distributing inbound API traffic equally across instances.

![Backend-SG Updated with Port Range 5000-5001](Screenshot/Security-Group/8.png)

---

### Bonus 2: Enable HTTPS on Nginx
To secure web traffic and encrypt client-server communication:
- **SSL Certificate Provisioning:** Generated a 2048-bit RSA self-signed SSL certificate with OpenSSL directly on `Web-Server` (`54.206.70.148`):
  ```bash
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=BD/ST=Dhaka/L=Dhaka/O=Ostad/OU=DevOps/CN=54.206.70.148"
  ```
- **Nginx HTTPS Virtual Host:** Configured Nginx to listen on Port `443` with modern TLS protocols (`TLSv1.2`, `TLSv1.3`) and strong ciphers.
- **Automatic HTTP to HTTPS Redirection:** Configured Port `80` to issue a permanent 301 redirect to `https://$host$request_uri`, ensuring all incoming plain HTTP requests are automatically upgraded to HTTPS.

#### Why does the browser display "Not secure" despite HTTPS being active?
1. **Encryption is Active & Secure:** Traffic between the client browser and Nginx reverse proxy is 100% encrypted end-to-end using TLSv1.2/TLSv1.3 with a 2048-bit RSA private key.
2. **Missing Public Root Certificate Authority (CA):** Web browsers maintain a pre-installed list of trusted root CAs (such as DigiCert, Sectigo, Let's Encrypt). Because this certificate was generated directly with OpenSSL (Self-Signed) without a third-party CA signature, the browser flags it with `NET::ERR_CERT_AUTHORITY_INVALID`.
3. **No Registered Domain Name:** Public Certificate Authorities (like Let's Encrypt) require a fully qualified domain name (FQDN) and do not issue free certificates for raw public IPv4 addresses.
4. **Standard Industry Practice:** For development, staging, testing environments, and infrastructure assignments without a custom domain, self-signed certificates are the industry standard for verifying TLS encryption.

#### 1. Browser Certificate Validation Prompt
The initial browser prompt acknowledging the self-signed SSL certificate on `https://54.206.70.148`.

![HTTPS Browser Warning and Verification](Screenshot/HTTPS/1.png)

#### 2. Live Application Running Securely over HTTPS
Application interface running over `https://54.206.70.148`, calculating metrics and successfully persisting health records.

![Live Application over HTTPS](Screenshot/HTTPS/2.png)

---

### Bonus 3: Automate Setup of Tiers with Scripts
To achieve complete Infrastructure-as-Code (IaC) readiness and repeatable deployment, end-to-end automation scripts were developed for all three tiers under the [`scripts/`](scripts/) directory:

1. **Database Tier Automation ([`scripts/setup-db.sh`](scripts/setup-db.sh)):**
   - Automatically installs PostgreSQL and contrib packages.
   - Creates the application database (`bmidb`), user (`bmi_user`), password, and permissions idempotently.
   - Provisions the `measurements` table schema and B-tree indexes.
   - Automatically edits `postgresql.conf` (`listen_addresses = '*'`) and `pg_hba.conf` for the backend subnet CIDR (`10.0.2.0/24`), then restarts the service.

2. **Application Tier Automation ([`scripts/setup-backend.sh`](scripts/setup-backend.sh)):**
   - Automatically configures NodeSource repo, installs Node.js 20 LTS, Git, build tools, and PM2.
   - Clones application repository and installs npm dependencies.
   - Dynamically writes `.env` configuration file with database credentials and port.
   - Daemonizes process under PM2 and enables systemd persistence.

3. **Web Tier Automation ([`scripts/setup-web.sh`](scripts/setup-web.sh)):**
   - Installs Nginx, Git, and Node.js 20.
   - Clones and builds the React SPA frontend into production static assets.
   - Deploys static files to `/var/www/bmi-tracker` with correct ownership.
   - Configures Nginx virtual host with reverse proxy routes and enables the site.

---

## 👤 Author Information

- **Name:** Ashaduzzaman
- **Email:** [ashaduzzaman5698@gmail.com](mailto:ashaduzzaman5698@gmail.com)
- **GitHub Profile:** [https://github.com/Faruque5698](https://github.com/Faruque5698)
- **Project Repository:** [https://github.com/Faruque5698/Ostad-Assingment-3-Tier-Application](https://github.com/Faruque5698/Ostad-Assingment-3-Tier-Application)




