# AGENTS.md

# Invest Kinda Right AI Agent Guide

## Project Overview

**Project:** Invest Kinda Right

A production-style intraday algorithmic trading platform.

### Tech Stack

  Layer           Technology
  --------------- -------------------------
  Backend         Java 21 + Spring Boot 3
  Frontend        Flutter
  Database        PostgreSQL
  Cache           Redis
  Broker          Zerodha Kite Connect
  Cloud           AWS EC2
  Containers      Docker & Docker Compose
  Reverse Proxy   Nginx
  CI/CD           GitHub Actions

------------------------------------------------------------------------

# Primary Goals

Build a maintainable trading platform with:

-   Authentication
-   Live market data
-   Candle generation
-   Technical indicators
-   Strategy engine
-   Paper trading
-   Risk management
-   Live trading
-   Mobile dashboard
-   Backtesting

Never optimize for premature complexity.

------------------------------------------------------------------------

# Repository Layout

``` text
invest-kinda-right/
│
├── backend/
├── frontend/
├── infrastructure/
│   ├── docker/
│   ├── nginx/
│   ├── aws/
│   └── terraform/   # future
│
├── docs/
│   ├── HLD.md
│   ├── LLD.md
│   ├── API.md
│   ├── DB_SCHEMA.md
│   ├── DEPLOYMENT.md
│   └── ROADMAP.md
│
├── scripts/
├── docker-compose.yml
├── README.md
└── AGENTS.md
```

------------------------------------------------------------------------

# Development Order

1.  Spring Boot setup
2.  PostgreSQL + Flyway
3.  JWT Authentication
4.  Flutter Login
5.  Kite Authentication
6.  Live Tick Streaming
7.  Redis Cache
8.  Candle Engine
9.  Indicator Engine
10. Strategy Engine
11. Paper Trading
12. Risk Engine
13. Live Orders
14. Docker
15. AWS Deployment
16. Backtesting

Do not implement live trading before paper trading.

------------------------------------------------------------------------

# Backend Rules

-   Java 21
-   Spring Boot 3
-   Constructor injection only
-   Thin controllers
-   Business logic in services
-   Repositories only access the database
-   DTOs for all API requests/responses
-   Global exception handler
-   Flyway for schema migrations
-   SLF4J logging

Package structure:

``` text
com.ganesh.investkindaright
├── auth
├── config
├── controller
├── dto
├── entity
├── repository
├── service
├── strategy
├── marketdata
├── risk
├── orders
├── websocket
├── scheduler
├── notification
├── common
└── exception
```

------------------------------------------------------------------------

# Frontend Rules

Flutter

Packages:

-   dio
-   provider
-   flutter_secure_storage
-   web_socket_channel

Screens:

-   Login
-   Dashboard
-   Watchlist
-   Orders
-   Positions
-   Analytics
-   Settings

------------------------------------------------------------------------

# Docker

Development:

-   Run Spring Boot from IntelliJ.
-   Run PostgreSQL and Redis using Docker.

Production:

Docker Compose services:

-   backend
-   postgres
-   redis
-   nginx

------------------------------------------------------------------------

# AWS

Initial deployment:

-   EC2
-   Docker Compose

Future upgrades:

-   RDS
-   ElastiCache
-   CloudWatch
-   Route53
-   ACM

------------------------------------------------------------------------

# Strategy Contract

``` java
public interface Strategy {
    Signal evaluate(Candle candle);
}
```

Strategies generate signals only.

Never place orders directly.

------------------------------------------------------------------------

# Risk Engine

Validate:

-   Daily loss
-   Max trades
-   Max exposure
-   Position sizing
-   Open positions

Risk validation always executes before order placement.

------------------------------------------------------------------------

# Security

-   Never hardcode secrets.
-   Use environment variables.
-   Move secrets to AWS Secrets Manager later.
-   Never log passwords or access tokens.

------------------------------------------------------------------------

# Git Strategy

Branches:

``` text
main
develop
feature/<name>
bugfix/<name>
```

------------------------------------------------------------------------

# AI Coding Instructions

When generating code:

-   Produce production-quality code.
-   Follow SOLID principles.
-   Prefer readability.
-   Keep methods small.
-   Add validation.
-   Add structured logging.
-   Add error handling.
-   Explain major architectural decisions.
-   Avoid unnecessary dependencies.
-   Use modern Java 21 features where appropriate.

------------------------------------------------------------------------

# Non-Goals (v1)

-   No Kubernetes
-   No Kafka
-   No RabbitMQ
-   No Microservices
-   No AI trading
-   No Multi-broker support

Build one robust monolithic application first.
