# 🚀 HNG DevOps Stage 1 — Automated Deployment Script

## 👤 Author
**Name:** Yekini Samson  
**Slack Username:** @Samsyne  

---

## 🎯 Task Objective
The goal of this task is to develop a Bash script (`deploy.sh`) that automates the setup, deployment, and configuration of a **Dockerized application** on a remote Linux server, with **Nginx** acting as a reverse proxy.

---

## ⚙️ What the Script Does
The `deploy.sh` script performs the following actions automatically:

1. **Builds a Docker image** for a simple web app.
2. **Runs the container** exposing it on port 8080.
3. **Configures Nginx** as a reverse proxy to forward HTTP requests (port 80) to the Docker container.
4. **Ensures idempotency** (safe to re-run).
5. **Logs every step** to `/var/log/deploy.log` for easy debugging.

---

## 🧩 Technologies Used
- **Bash scripting**
- **Docker & Docker Compose**
- **Nginx**
- **Amazon Linux (EC2 instance)**

---

## 🧪 How to Run
Clone the repository and run the script:

```bash
git clone https://github.com/Samsyne/hng-devops-stage1.git
cd hng-devops-stage1
chmod +x deploy.sh
sudo ./deploy.sh

# hng-devops-stage1
Devops Automated Deployment Script
