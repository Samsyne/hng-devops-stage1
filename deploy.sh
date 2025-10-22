#!/bin/bash
# =========================================================
# 🚀 Samson's Stage 1 Bot-Compliant Deployment Script
# =========================================================

set -e  # Exit on any error
trap 'echo "❌ An error occurred. Check the log for details."; exit 1' ERR

# --- Log File Setup ---
LOGFILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "========================================================="
echo "🚀 Starting Automated Deployment - $(date)"
echo "========================================================="

# --- STEP 1: Collect User Inputs ---
read -p "Enter Git Repository URL: " GIT_URL
read -p "Enter Git Personal Access Token (PAT): " PAT
read -p "Enter Branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}
read -p "Enter Remote Server Username (e.g., ec2-user): " SSH_USER
read -p "Enter Remote Server IP Address: " SSH_IP
read -p "Enter path to SSH key (e.g., /home/user/mykey.pem): " SSH_KEY
read -p "Enter Application port (container internal port, e.g., 8080): " APP_PORT

# --- Input Validation ---
if [[ -z "$GIT_URL" || -z "$PAT" || -z "$SSH_USER" || -z "$SSH_IP" || -z "$SSH_KEY" || -z "$APP_PORT" ]]; then
    echo "❌ Error: All fields are required!"
    exit 1
fi

# --- STEP 2: Git Operations ---
REPO_NAME=$(basename "$GIT_URL" .git)
if [ -d "$REPO_NAME" ]; then
    echo "📦 Repository exists. Pulling latest changes..."
    cd "$REPO_NAME"
    git pull
else
    echo "📥 Cloning repository..."
    git clone "https://${PAT}@${GIT_URL#https://}" "$REPO_NAME"
    cd "$REPO_NAME"
fi

git checkout "$BRANCH"
echo "✅ Git operations completed."

# --- STEP 3: SSH Connectivity Check ---
echo "🧠 Testing SSH connection to $SSH_USER@$SSH_IP ..."
ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SSH_IP" "echo SSH connection successful." || {
    echo "❌ SSH connection failed"
    exit 1
}

# --- STEP 4: Prepare Remote Server ---
echo "⚙️ Preparing remote server..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_IP" <<EOF
set -e
echo "📦 Updating system packages..."
sudo yum update -y
echo "🐳 Installing Docker..."
sudo amazon-linux-extras enable docker
sudo yum install -y docker git nginx
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $SSH_USER
EOF

# --- STEP 5: Deploy Dockerized Application ---
echo "🚀 Deploying Docker container..."
scp -i "$SSH_KEY" -r . "$SSH_USER@$SSH_IP:/home/$SSH_USER/app"

ssh -i "$SSH_KEY" "$SSH_USER@$SSH_IP" <<EOF
cd /home/$SSH_USER/app
sudo docker stop myapp || true
sudo docker rm myapp || true
sudo docker build -t myapp .
sudo docker run -d -p $APP_PORT:80 --name myapp myapp
EOF

# --- STEP 6: Configure Nginx Reverse Proxy ---
echo "🌍 Configuring Nginx..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_IP" <<EOF
sudo tee /etc/nginx/conf.d/dockerapp.conf > /dev/null <<NGINXCONF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINXCONF
sudo nginx -t
sudo systemctl reload nginx
EOF

# --- STEP 7: Deployment Validation ---
echo "✅ Validating deployment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SSH_IP" <<EOF
sudo systemctl status docker | grep active
sudo docker ps
curl -I localhost || echo "⚠️ App not reachable"
EOF

# --- STEP 8: Optional Cleanup ---
if [[ "$1" == "--cleanup" ]]; then
    echo "🧹 Cleaning up deployment..."
    ssh -i "$SSH_KEY" "$SSH_USER@$SSH_IP" <<EOF
sudo docker stop myapp || true
sudo docker rm myapp || true
sudo rm -rf /home/$SSH_USER/app
sudo rm -f /etc/nginx/conf.d/dockerapp.conf
sudo systemctl reload nginx
EOF
    echo "✅ Cleanup complete."
    exit 0
fi

echo "🎉 Deployment complete! Logs saved in $LOGFILE"

