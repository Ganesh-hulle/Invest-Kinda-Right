# Invest Kinda Right — AWS Production Deployment Master Guide

> **Prompt for AI Assistant / Cloud DevOps Guide:**
> 
> "Act as a Senior Cloud DevOps Architect and Lead Backend Engineer. You are guiding me step-by-step through deploying the **Invest Kinda Right** production intraday algorithmic trading platform to AWS.
> 
> **Instructions for the AI:**
> 1. Guide me **one phase at a time**. Do not dump all instructions at once.
> 2. For each step, provide the exact shell commands, explain what they do, and prompt me to confirm when done before moving to the next step.
> 3. Verify security at every phase (never expose database or Redis ports to the public internet, restrict SSH, enforce HTTPS/WSS).
> 4. Ensure WebSocket proxying (`/ws/market-data`) is explicitly configured with HTTP `Upgrade` and `Connection` headers for real-time market data streaming.
> 5. Follow the project architecture, tech stack, and configurations outlined in this document."

---

## 1. Project Overview & Architecture

**Invest Kinda Right (IKR)** is a production-grade intraday algorithmic trading platform integrating with Zerodha Kite Connect for live market data, candle generation, technical indicators (EMA 9/20, VWAP, RSI 14, MACD, SuperTrend), paper trading, and risk management.

### Tech Stack

| Layer | Technology | Production Role |
|---|---|---|
| **Backend** | Java 21, Spring Boot 3.4+, Maven | REST APIs, Strategy Engine, WebSocket Server, Risk Engine |
| **Database** | PostgreSQL 16 | Relational store for users, orders, positions, risk limits, market candles |
| **Cache & Pub/Sub** | Redis 7 (Alpine) | Ticks cache, indicator cache, session state |
| **Reverse Proxy** | Nginx 1.25+ | SSL termination, reverse proxy for REST (`/api/`) and WebSocket (`/ws/`) |
| **Broker Integration** | Zerodha Kite Connect 3 API | Market quotes, historical candles, binary WebSocket tick streamer |
| **Frontend** | Flutter (Mobile Android/iOS & Web) | Live trading companion dashboard, watchlist, order placement |
| **Cloud Host** | AWS EC2 (Ubuntu 24.04 LTS) | Monolithic container host running Docker Compose |
| **SSL / TLS** | Let's Encrypt (Certbot) | Free auto-renewing SSL certificate for HTTPS & WSS |

---

## 2. Target Architecture on AWS (Phase 1: EC2 + Docker Compose)

Per the project roadmap (`AGENTS.md`), the v1 deployment is a robust, maintainable monolith on AWS EC2 before migrating to managed services (RDS, ElastiCache, ALB) in v2.

```
                         Internet
                            │
               HTTPS (443)  │  WSS (443)
                            ▼
              ┌───────────────────────────┐
              │     AWS Elastic IP        │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │     AWS EC2 Security      │
              │  Group (Port 80, 443, 22) │
              └─────────────┬─────────────┘
                            │
     ┌──────────────────────▼──────────────────────┐
     │  AWS EC2 Instance (Ubuntu 24.04 LTS)        │
     │                                             │
     │  ┌───────────────────────────────────────┐  │
     │  │ Nginx (Reverse Proxy & SSL Certbot)   │  │
     │  │ - Port 80 -> Redirect to 443 (HTTPS)  │  │
     │  │ - /api/*  -> backend:8080             │  │
     │  │ - /ws/*   -> backend:8080 (Upgrade)   │  │
     │  │ - /       -> Flutter Web (optional)   │  │
     │  └───────────────────┬───────────────────┘  │
     │                      │ Docker Network       │
     │         ┌────────────┼────────────┐         │
     │         ▼            ▼            ▼         │
     │   ┌───────────┐┌───────────┐┌───────────┐   │
     │   │  Backend  ││ PostgreSQL││   Redis   │   │
     │   │ (Java 21) ││   v16     ││    v7     │   │
     │   │ Port 8080 ││ Port 5432 ││ Port 6379 │   │
     │   │ (Internal)││ (Internal)││ (Internal)│   │
     │   └─────┬─────┘└─────▲─────┘└─────▲─────┘   │
     │         │            │            │         │
     │         └────────────┴────────────┘         │
     │                                             │
     │  Persistent Volumes:                        │
     │  - postgres_data -> /var/lib/postgresql/data│
     │  - redis_data    -> /data                   │
     │  - certbot_certs -> /etc/letsencrypt        │
     └─────────────────────────────────────────────┘
```

---

## 3. Step-by-Step Execution Plan

### Step 1: AWS Account, Security Group & EC2 Instance Setup

1. **Instance Sizing Recommendation**:
   - **Instance Type**: `t3.medium` (2 vCPU, 4 GB RAM) or `t3.large` (2 vCPU, 8 GB RAM).
   - **OS**: Ubuntu Server 24.04 LTS (64-bit x86).
   - **Storage**: 30–50 GB gp3 SSD (general purpose).
2. **Security Group Inbound Rules**:
   - `SSH` (Port 22): Source = **My IP** (never allow `0.0.0.0/0` for SSH).
   - `HTTP` (Port 80): Source = `0.0.0.0/0` (for Let's Encrypt challenge & redirect).
   - `HTTPS` (Port 443): Source = `0.0.0.0/0` (for encrypted app traffic).
   - **Important**: Ports `5432` (Postgres), `6379` (Redis), and `8080` (Spring Boot) must **NOT** be open to the public internet.
3. **Allocate Elastic IP**:
   - Allocate an Elastic IP in AWS VPC and associate it with the EC2 instance so the public IP remains static across reboots.
4. **Configure DNS**:
   - In your domain DNS manager (GoDaddy, Cloudflare, Namecheap, Route53), add an **A record**:
     - `api.yourdomain.com` $\to$ `<Elastic IP>`

---

### Step 2: EC2 Server Initialization & Docker Installation

SSH into the instance:
```bash
ssh -i /path/to/your-key.pem ubuntu@<ELASTIC_IP>
```

Update system and install Docker CE + Docker Compose:
```bash
# Update and install base packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg lsb-release git ufw htop

# Add Docker official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine & Compose plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow non-root docker execution
sudo usermod -aG docker $USER
newgrp docker

# Verify installations
docker --version
docker compose version
```

Configure basic firewall (UFW):
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

---

### Step 3: Production Docker Configuration Files

The deployment requires three core production files created on the server:

#### 1. Backend Multi-Stage Dockerfile (`backend/Dockerfile`)

```dockerfile
# ── Build Stage ──
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /build

# Cache Maven dependencies
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B

# Copy source code and build production jar
COPY src src
RUN ./mvnw clean package -DskipTests -B

# ── Runtime Stage ──
FROM eclipse-temurin:21-jre-alpine AS runner
WORKDIR /app

# Run as non-root user for security
RUN addgroup -S ikrgroup && adduser -S ikruser -G ikrgroup
USER ikruser

# Copy jar from builder
COPY --from=builder /build/target/*.jar app.jar

# JVM Performance flags tuned for 2-4GB containers
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

EXPOSE 8080
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dspring.profiles.active=prod -jar app.jar"]
```

#### 2. Production Docker Compose (`docker-compose.prod.yml`)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: ikr-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_NAME:-ikr}
      POSTGRES_USER: ${DB_USERNAME:-ikr}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - ikr-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USERNAME:-ikr} -d ${DB_NAME:-ikr}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: ikr-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - ikr-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: ikr-backend
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      SPRING_PROFILES_ACTIVE: prod
      DB_URL: jdbc:postgresql://postgres:5432/${DB_NAME:-ikr}
      DB_USERNAME: ${DB_USERNAME:-ikr}
      DB_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: ${REDIS_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXPIRATION: ${JWT_EXPIRATION:-86400000}
      KITE_API_KEY: ${KITE_API_KEY}
      KITE_API_SECRET: ${KITE_API_SECRET}
      KITE_REDIRECT_URL: ${KITE_REDIRECT_URL}
      KITE_TOKEN_ENCRYPTION_KEY: ${KITE_TOKEN_ENCRYPTION_KEY}
      WEBSOCKET_ALLOWED_ORIGINS: ${WEBSOCKET_ALLOWED_ORIGINS:-*}
    networks:
      - ikr-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/actuator/health"]
      interval: 15s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:1.27-alpine
    container_name: ikr-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./infrastructure/nginx/conf.d:/etc/nginx/conf.d:ro
      - certbot_conf:/etc/letsencrypt:ro
      - certbot_www:/var/www/certbot:ro
    depends_on:
      - backend
    networks:
      - ikr-network

  certbot:
    image: certbot/certbot:latest
    container_name: ikr-certbot
    volumes:
      - certbot_conf:/etc/letsencrypt
      - certbot_www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12d & wait $${!}; done;'"

networks:
  ikr-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  certbot_conf:
  certbot_www:
```

#### 3. Production Nginx Configuration (`infrastructure/nginx/conf.d/app.conf`)

```nginx
# Upstream Spring Boot application
upstream backend_cluster {
    server backend:8080;
    keepalive 32;
}

# HTTP — Redirect all traffic to HTTPS & serve Certbot challenges
server {
    listen 80;
    server_name api.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS — SSL Termination, REST Proxy, and WebSocket Upgrade
server {
    listen 443 ssl;
    http2 on;
    server_name api.yourdomain.com;

    # SSL Certificates (managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    # Modern SSL security headers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    # REST APIs
    location /api/ {
        proxy_pass http://backend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90s;
        proxy_connect_timeout 60s;
    }

    # Actuator Health endpoint
    location /actuator/ {
        proxy_pass http://backend_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Market Data WebSocket (STOMP / SockJS / Native WS)
    location /ws/ {
        proxy_pass http://backend_cluster;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400s; # Keep connection open 24h
        proxy_send_timeout 86400s;
    }
}
```

---

### Step 4: Environment Variables & Secrets Setup (`.env.prod`)

Create `.env.prod` on the EC2 server (never commit this file to Git):

```bash
# ── Database ──
DB_NAME=ikr
DB_USERNAME=ikr_admin
DB_PASSWORD=YOUR_STRONG_POSTGRES_PASSWORD_MIN_24_CHARS

# ── Redis ──
REDIS_PASSWORD=YOUR_STRONG_REDIS_PASSWORD_MIN_24_CHARS

# ── JWT Security ──
# Generate with: openssl rand -base64 64
JWT_SECRET=YOUR_GENERATED_64_CHAR_BASE64_SECRET
JWT_EXPIRATION=86400000

# ── Zerodha Kite Connect ──
KITE_API_KEY=your_zerodha_api_key
KITE_API_SECRET=your_zerodha_api_secret
KITE_REDIRECT_URL=https://api.yourdomain.com/api/v1/kite/callback
# Generate 32-byte key: openssl rand -hex 16
KITE_TOKEN_ENCRYPTION_KEY=YOUR_32_CHAR_HEX_ENCRYPTION_KEY

# ── CORS & WebSocket ──
WEBSOCKET_ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

---

### Step 5: SSL Certificate Generation via Certbot

To obtain the initial SSL certificate from Let's Encrypt before launching Nginx with SSL:

1. Create temporary standalone certificate:
   ```bash
   sudo docker run -it --rm --name certbot \
     -p 80:80 \
     -v certbot_conf:/etc/letsencrypt \
     -v certbot_www:/var/www/certbot \
     certbot/certbot certonly \
     --standalone \
     -d api.yourdomain.com \
     --agree-tos \
     -m your-email@domain.com \
     --no-eff-email
   ```
2. Verify certificates were generated:
   ```bash
   sudo ls -l /var/lib/docker/volumes/certbot_conf/_data/live/api.yourdomain.com/
   # Should list fullchain.pem and privkey.pem
   ```

---

### Step 6: Launch & Verify Backend Services

```bash
# Pull and start all containers with the production configuration
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

# Monitor live startup logs
docker compose -f docker-compose.prod.yml logs -f backend
```

Verify healthcheck:
```bash
curl -I https://api.yourdomain.com/actuator/health
# Expected: HTTP/2 200 OK {"status":"UP"}
```

---

### Step 7: Update Zerodha Developer Console

1. Navigate to [Zerodha Kite Developer Console](https://kite.trade/).
2. Select your app.
3. Update the **Redirect URL** to:
   ```
   https://api.yourdomain.com/api/v1/kite/callback
   ```
4. Save changes.

---

### Step 8: Update Flutter App to Connect to AWS

In the Flutter mobile or web client:
1. Open [`lib/core/network/dio_client.dart`](file:///c:/Users/hulle/OneDrive/Desktop/PROJECT/Invest-Kinda-Right/frontend/lib/core/network/dio_client.dart).
2. Point the default base URL to your production AWS domain:
   ```dart
   static String _baseUrl = 'https://api.yourdomain.com';
   ```
3. In [`lib/core/websocket/market_ws_service.dart`](file:///c:/Users/hulle/OneDrive/Desktop/PROJECT/Invest-Kinda-Right/frontend/lib/core/websocket/market_ws_service.dart):
   Ensure the WebSocket connects to:
   ```dart
   wss://api.yourdomain.com/ws/market-data
   ```
4. Or, users can dynamically update the Base URL via the in-app **Settings $\to$ API Configuration** screen.

---

## 4. Operational Maintenance & Runbook

### Log Inspection
```bash
# Follow backend application logs
docker compose -f docker-compose.prod.yml logs -f --tail=100 backend

# Follow Nginx access and error logs
docker compose -f docker-compose.prod.yml logs -f --tail=100 nginx

# Check database queries and errors
docker compose -f docker-compose.prod.yml logs -f --tail=100 postgres
```

### Database Backup & Restore
```bash
# Automated Daily Backup Script
docker exec -t ikr-postgres pg_dump -U ikr ikr | gzip > ~/backups/ikr_db_$(date +%F).sql.gz

# Restore Database Backup
gunzip < ~/backups/ikr_db_2026-09-08.sql.gz | docker exec -i ikr-postgres psql -U ikr -d ikr
```

### Zero-Downtime Application Updates
When new code is pushed to your Git repository:
```bash
git pull origin main
docker compose -f docker-compose.prod.yml --env-file .env.prod build backend
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --no-deps backend
```

---

## 5. Next Phase: Cloud-Native Scaling (v2 Preview)

When trading volume and concurrent users grow:
1. **Database**: Move from EC2 container to **AWS RDS PostgreSQL** (Multi-AZ with automated snapshots).
2. **Cache**: Move from EC2 container to **AWS ElastiCache for Redis** (Cluster mode enabled).
3. **Load Balancing**: Add **AWS Application Load Balancer (ALB)** with AWS Certificate Manager (ACM) free SSL.
4. **Secrets**: Migrate `.env.prod` to **AWS Secrets Manager** with IAM role access.
5. **Monitoring**: Stream container metrics and SLF4J logs to **AWS CloudWatch**.
