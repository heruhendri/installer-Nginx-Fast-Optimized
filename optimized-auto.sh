#!/bin/bash
set -euo pipefail

echo "================================================"
echo "  NGINX AUTO INSTALLER (SMART RESOURCE ADAPT) BY HENDRI"
echo "================================================"

# ===============================
# DETEKSI RESOURCE VPS
# ===============================
CPU=$(nproc)
RAM_MB=$(free -m | awk '/Mem:/ {print $2}')

echo "[+] Deteksi CPU: $CPU core"
echo "[+] Deteksi RAM: $RAM_MB MB"

# ===============================
# SETTING PARAMETER OTOMATIS
# ===============================
if [[ $RAM_MB -lt 2048 ]]; then
    PROFILE="Kecil"
    WORKER_CONN=1024
    MAX_CHILD=5
elif [[ $RAM_MB -lt 8192 ]]; then
    PROFILE="Medium"
    WORKER_CONN=2048
    MAX_CHILD=10
else
    PROFILE="Besar"
    WORKER_CONN=4096
    MAX_CHILD=20
fi

PM_START=$((MAX_CHILD/3))
PM_MIN=$((PM_START))
PM_MAX=$((MAX_CHILD/2 + PM_START))

GZIP_LEVEL=5

echo "[+] Profil VPS: $PROFILE"
echo "[+] Worker Connections: $WORKER_CONN"
echo "[+] PHP-FPM Max Children: $MAX_CHILD"

# ===============================
# INSTALL DEPENDENSI
# ===============================
apt update
apt install -y nginx php*-fpm certbot python3-certbot-nginx ufw

# Backup config lama
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%s)

# ===============================
# NGINX CONFIG
# ===============================
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes $CPU;

events {
    worker_connections $WORKER_CONN;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    client_max_body_size 200M;
    keepalive_timeout 65;
    keepalive_requests 500;

    gzip on;
    gzip_comp_level $GZIP_LEVEL;
    gzip_min_length 10240;
    gzip_proxied any;
    gzip_vary on;

    include /etc/nginx/mime.types;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# ===============================
# GENIEACS REVERSE PROXY
# ===============================
cat > /etc/nginx/conf.d/genieacs.conf <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;

        proxy_connect_timeout 180s;
        proxy_send_timeout 180s;
        proxy_read_timeout 180s;
        send_timeout 180s;
    }
}
EOF

# ===============================
# SSL OPTIONAL
# ===============================
read -p "Install SSL Let's Encrypt? (y/n): " SSL_USE
if [[ "$SSL_USE" =~ ^[Yy]$ ]]; then
    read -p "Domain SSL: " DOMAIN
    read -p "Email: " EMAIL
    certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
    echo "[+] SSL aktif untuk $DOMAIN"
else
    echo "[+] SSL dilewati..."
fi

# ===============================
# BBR/BBR2 SAFE
# ===============================
activate_bbr2() {
    echo "[?] Aktifkan BBR/BBR2 jika kernel support? (y/n, timeout 10s): "
    read -t 10 ans || ans="n"
    if [[ "$ans" != "y" ]]; then
        echo "[!] BBR2 dibatalkan."
        return
    fi
    if [[ ! -d /proc/sys/net/ipv4 ]]; then
        echo "[!] NAT VPS/LXC: skip BBR"
        return
    fi
    AVAILABLE=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{print $3}')
    if echo "$AVAILABLE" | grep -q "bbr2"; then
        sysctl -w net.core.default_qdisc=fq 2>/dev/null || true
        sysctl -w net.ipv4.tcp_congestion_control=bbr2 2>/dev/null || true
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr2" >> /etc/sysctl.conf
        sysctl -p 2>/dev/null || true
        echo "[✓] BBR2 aktif."
        return
    elif echo "$AVAILABLE" | grep -q "bbr"; then
        sysctl -w net.core.default_qdisc=fq 2>/dev/null || true
        sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || true
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p 2>/dev/null || true
        echo "[✓] BBR aktif."
        return
    fi
    echo "[!] Kernel tidak mendukung BBR/BBR2."
}
activate_bbr2

# ===============================
# FIREWALL UFW SAFE
# ===============================
read -p "Aktifkan firewall anti-DDOS? (y/n): " FW_USE
if [[ "$FW_USE" =~ ^[Yy]$ ]]; then
    ufw allow OpenSSH
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 3000/tcp
    ufw allow 7547/tcp
    ufw allow 7557/tcp
    ufw allow 7567/tcp
    ufw limit 80/tcp
    ufw limit 443/tcp
    echo "y" | ufw enable
fi

# ===============================
# PHP-FPM OPTIMIZATION
# ===============================
for PHPV in /etc/php/*/fpm/pool.d/www.conf; do
    if [[ -f "$PHPV" ]]; then
        sed -i "s/^pm.max_children =.*/pm.max_children = $MAX_CHILD/" "$PHPV"
        sed -i "s/^pm.start_servers =.*/pm.start_servers = $PM_START/" "$PHPV"
        sed -i "s/^pm.min_spare_servers =.*/pm.min_spare_servers = $PM_MIN/" "$PHPV"
        sed -i "s/^pm.max_spare_servers =.*/pm.max_spare_servers = $PM_MAX/" "$PHPV"
    fi
done

systemctl restart php*-fpm 2>/dev/null || true
systemctl restart nginx

echo ""
echo "================================================"
echo " INSTALASI SELESAI! NGINX + GenieACS siap"
echo " Profil VPS: $PROFILE → Optimasi otomatis"
echo " Proxy timeout tinggi → minim 504 di HTTPS"
echo "================================================"
