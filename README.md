# 🦍 Kong Gateway Setup using Docker

This repository contains a simple setup to run **Kong Gateway** Community Version using **Docker Compose** in **DB-less mode**, along with optional configuration for **Prometheus monitoring** and **Kong declarative configuration**.

---

## 📁 Folder / File Structure

```
├── docker-compose.yml     # Main Docker Compose configuration file
├── kong.yml               # Declarative Kong configuration (Routes, Services, Plugins, etc.)
└── prometheus.yml         # Prometheus configuration for monitoring
```

---

## 🚀 Getting Started

### 1. Prerequisites

Make sure you have the following installed on your system:

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

Verify installation:

```bash
docker --version
docker compose version
```

---

### 2. Start the Kong Gateway Stack

To start all the services defined in your `docker-compose.yml` file:

```bash
docker compose up -d
```

This will:
- Launch **Kong Gateway**
- Load declarative configuration from `kong.yml`
- Start **Prometheus** and **Grafana** for metrics monitoring
Once started, verify that the containers are running:

```bash
docker ps
```

---

### 3. Accessing Kong

| Service | URL | Description |
|----------|-----|-------------|
| **Kong Admin API** | `http://localhost:8001` | Manage and inspect Kong configuration |
| **Kong Proxy (Public)** | `http://localhost:8000` | Route external API traffic |
| **Kong Manager** | `http://localhost:8002` | Web UI for managing Kong |
| **Prometheus** | `http://localhost:9090` | View collected metrics |
| **Grafana** | `http://localhost:9000` | View collected metrics |

---

### 4. Stop and Remove Containers

To gracefully stop all containers:

```bash
docker compose down
```

If you want to remove all volumes and networks created by this stack:

```bash
docker compose down -v
```

---

### 5. View Logs

To see logs for all services:

```bash
docker compose logs -f
```

---

### 6. Rebuilding / Updating

If you modify configuration files (e.g., `kong.yml`, `prometheus.yml`) and want to restart cleanly:

```bash
docker compose down
docker compose up -d
```

## 📜 License

This project is provided for educational and setup purposes.  
Refer to [Kong Gateway Documentation](https://docs.konghq.com/) for full configuration options.

---
