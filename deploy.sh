#!/bin/bash

# =========================================================
# Samson's Docker + Nginx Deployment Script
# =========================================================

# Exit immediately if a command exits with a non-zero status
set -e

# Log file location
LOGFILE="/var/log/deploy.log"

# Redirect stdout and stderr to log file and terminal
exec > >(tee -a "$LOGFILE") 2>&1

echo "========================================================="
echo "🚀 Starting Deployment - $(date)"
echo "========================================================="

# Step 1: Build Docker image
echo "🔧 Building Docker image..."
if sudo docker build -t myapp .; then
  echo "✅ Docker image built successfully"
else
  echo "❌ Docker build failed" >&2
  exit 1
fi

# Step 2: Stop and remove any existing container
echo "🧹 Cleaning up old containers..."
if sudo docker ps -q --filter "name=myapp" | grep -q .; then
  sudo docker stop myapp && sudo docker rm myapp
  echo "✅ Old container removed"
else
  echo "ℹ️ No old container found"
fi

# Step 3: Run new container
echo "🐳 Running new Docker container..."
if sudo docker run -d --name myapp -p 8080:80 myapp; then
  echo "✅ Docker container running successfully on port 8080"
else
  echo "❌ Failed to run Docker container" >&2
  exit 1
fi

# Step 4: Configure Nginx reverse proxy
echo "🧠 Configuring Nginx reverse proxy..."

# Remove default config if it exists
sudo rm -f /etc/nginx/conf.d/default.conf

# Create new Nginx config file
sudo bash -c 'cat > /etc/nginx/conf.d/dockerapp.conf <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF'

# Test and reload Nginx
sudo nginx -t && sudo systemctl reload nginx

echo "✅ Nginx reverse proxy configured successfully!"

# Step 5: Verify everything
echo "🔍 Checking running services..."
sudo docker ps
sudo systemctl status nginx --no-pager

echo "========================================================="
echo "🎉 Deployment completed successfully at $(date)"
echo "========================================================="

