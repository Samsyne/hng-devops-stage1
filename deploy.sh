#!/bin/bash

# =========================================================
# Samson's Stage 1 DevOps Deployment Script (Idempotent)
# =========================================================

set -e
trap 'echo "❌ Error occurred at line $LINENO"; exit 1' ERR

# ------------------------------
# Logging
# ------------------------------
LOGFILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "========================================================="
echo "🚀 Starting Deployment - $(date)"
echo "========================================================="

# ------------------------------
# Step 1: User Input
# ------------------------------
read -p "Enter Git repository URL: " GIT_REPO
read -p "Enter Git Personal Access Token (PAT): " GIT_PAT
read -p "Enter branch name [default: main]: " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}
read -p "Enter EC2 username: " SSH_USER
read -p "Enter EC2 IP address: " SSH_HOST
read -p "Enter SSH private key path (e.g., ~/.ssh/mykey.pem): " SSH_KEY
read -p "Enter application port (container internal port, e.g., 8080): " APP_PORT

# ------------------------------
# Step 2: Git clone / pull
# ------------------------------
if [ ! -d "app_repo" ]; then
    echo "Cloning repository..."
    git clone -b "$GIT_BRANCH" https://$GIT_PAT@$GIT_REPO app_repo
else
    echo "Repository exists, pulling latest changes..."
    cd app_repo
    git fetch
    git checkout "$GIT_BRANCH"
    git pull
    cd ..
fi

# ------------------------------
# Step 3: SSH connectivity check
# ------------------------------
echo "🧠 Testing SSH connection..."
ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 $SSH_USER@$SSH_HOST "echo 'SSH OK'"

# ------------------------------
# Step 4: Remote Server Preparation
# ------------------------------
ssh -i "$SSH_KEY" $SSH_USER@$SSH_HOST bash <<'EOF'
set -e

# Update packages
sudo yum update -y

# Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
    sudo amazon-linux-extras install docker -y
fi
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Install Nginx if missing
if ! command -v nginx >/dev/null 2>&1; then
    sudo amazon-linux-extras install nginx1 -y
fi
sudo systemctl enable nginx
sudo systemctl start nginx
EOF

# ------------------------------
# Step 5: Deploy Dockerized App
# ------------------------------
# Stop/remove old container
ssh -i "$SSH_KEY" $SSH_USER@$SSH_HOST <<EOF
sudo docker ps -q --filter "name=myapp" | grep -q . && sudo docker stop myapp || true
sudo docker ps -aq --filter "name=myapp" | grep -q . && sudo docker rm myapp || true
sudo docker image rm myapp || true

# Free the port
sudo lsof -i :$APP_PORT -t | xargs -r sudo kill -9

# Copy files
rm -rf ~/app_repo/*
scp -i "$SSH_KEY" -r app_repo/* $USER@$HOSTNAME:~/app_repo/

# Build and run
cd ~/app_repo
sudo docker build -t myapp .
sudo docker run -d -p $APP_PORT:80 --name myapp myapp
EOF

# ------------------------------
# Step 6: Configure Nginx Reverse Proxy
# ------------------------------
ssh -i "$SSH_KEY" $SSH_USER@$SSH_HOST <<EOF
sudo rm -f /etc/nginx/conf.d/dockerapp.conf
sudo bash -c 'cat > /etc/nginx/conf.d/dockerapp.conf <<NGINX
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:'"$APP_PORT"';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX'

sudo nginx -t
sudo systemctl reload nginx
EOF

# ------------------------------
# Step 7: Deployment Validation
# ------------------------------
ssh -i "$SSH_KEY" $SSH_USER@$SSH_HOST <<EOF
echo "✅ Checking Docker service..."
sudo systemctl status docker | grep active

echo "✅ Checking container..."
sudo docker ps

echo "✅ Checking Nginx..."
curl -I localhost || echo "⚠️ App not reachable"
EOF

# ------------------------------
# Step 8: Optional Cleanup
# ------------------------------
if [[ "$1" == "--cleanup" ]]; then
ssh -i "$SSH_KEY" $SSH_USER@$SSH_HOST <<EOF
sudo docker stop myapp || true
sudo docker rm myapp || true
sudo docker image rm myapp || true
sudo rm -rf ~/app_repo
sudo rm -f /etc/nginx/conf.d/dockerapp.conf
sudo systemctl reload nginx
EOF
echo "✅ Cleanup complete"
exit 0
fi

echo "========================================================="
echo "🎉 Deployment completed successfully at $(date)"
echo "Logs saved at $LOGFILE"
echo "========================================================="

