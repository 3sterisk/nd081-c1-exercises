#!/bin/bash
set -e
set -o pipefail

# === CONFIG ===
WEB_DIR="$(dirname "$0")/web"   # "web" folder is in the same location as this script
VENV_DIR="$WEB_DIR/venv"
REQ_FILE="$WEB_DIR/requirements.txt"
APP_ENTRY="application.py"
PYTHON="python3"

echo "[INFO] Updating system and installing dependencies..."
sudo apt-get -y update && sudo apt-get -y install nginx python3-venv

# === Configure Nginx ===
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
NGINX_CONF="$NGINX_SITES_AVAILABLE/site.conf"

echo "[INFO] Configuring Nginx..."
# Remove default config if exists
if [[ -L "$NGINX_SITES_ENABLED/default" ]]; then
    sudo unlink "$NGINX_SITES_ENABLED/default"
fi

# Create new site.conf
sudo tee "$NGINX_CONF" > /dev/null <<EOL
server {
    listen 80;
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

# Symlink to sites-enabled
if [[ ! -L "$NGINX_SITES_ENABLED/site.conf" ]]; then
    sudo ln -s "$NGINX_CONF" "$NGINX_SITES_ENABLED/site.conf"
fi

# Restart nginx
echo "[INFO] Restarting Nginx..."
sudo systemctl restart nginx
sudo systemctl enable nginx

# === Python Virtual Environment ===
echo "[INFO] Setting up Python virtual environment..."
if [[ ! -d "$VENV_DIR" ]]; then
    $PYTHON -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

# Upgrade pip & install dependencies
echo "[INFO] Installing Python dependencies..."
pip install --upgrade pip
pip install -r "$REQ_FILE"

# === Run Application ===
echo "[INFO] Starting application..."
cd "$WEB_DIR"
$PYTHON "$APP_ENTRY"
