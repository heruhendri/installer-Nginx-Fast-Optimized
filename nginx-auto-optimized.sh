#!/bin/bash
set -euo pipefail

echo "================================================"
echo "  NGINX AUTO INSTALLER (MODULAR FEATURES) BY HENDRI"
echo "================================================"
echo ""
echo "Pilih profile optimasi server:"
echo "1) VPS Kecil     (1GB RAM - 1 CPU)"
echo "2) VPS Medium    (2-4GB RAM - 2 CPU)"
echo "3) VPS Besar     (8-10GB RAM - 4+ CPU)"
echo ""

read -p "Masukkan pilihan (1/2/3): " OPT

# ===========================================
# PROFIL
# ===========================================
if [[ "$OPT" == "1" ]]; then
    WORKER_CONN=1024
    MAX_CHILD=5
    PM_START=2
    PM_MIN=2
    PM_MAX=4
    GZIP_LEVEL=4
elif [[ "$OPT" == "2" ]]; then
    WORKER_CONN=2048
    MAX_CHILD=10
    PM_START=3
    PM_MIN=3
    PM_MAX=6
    GZIP_LEVEL=5
elif [[ "$OPT" == "3" ]]; then
    WORKER_CONN=4096
    MAX_CHILD=20
    PM_START=6
    PM_MIN=6
    PM_MAX=12
    GZIP_LEVEL=6
else
    echo "Pilihan salah!"
    exit 1
fi

# ===========================================
# INSTALL NGINX
# ===========================================
apt update
apt install -y nginx

echo "[+] Backup nginx.conf lama..."
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%s)

# ===========================================
# NGINX CONF OPTIMIZED
# ===========================================
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;

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

# ===========================================
# GENIEACS PROXY SAFE (MINIM 504)
# ===========================================
cat > /etc/nginx/conf.d/genieacs.conf <<'EOF'
# Reverse proxy untuk GenieACS UI dan CWMP
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

# Optional: HTTPS redirect block nanti di certbot
EOF

# ===========================================
# SSL LET'S ENCRYPT
# ===========================================
read -p "Install SSL Let's Encrypt? (y/n): " SSL_USE
if [[ "$SSL_USE" =~ ^[Yy]$ ]]; then
    read -p "Domain SSL: " DOMAIN
    read -p "Email: " EMAIL

    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

    echo "[+] SSL aktif untuk $DOMAIN"
fi

# ===========================================
# BBR SAFE
# ===========================================
activate_bbr2() {
    read -p "[?] Aktifkan BBR/BBR2 jika kernel support? (y/n): " ans
    if [[ "$ans" != "y" ]]; then return; fi
    if [[ ! -d /proc/sys/net/ipv4 ]]; then
        echo "[!] NAT VPS/LXC: skip BBR"
        return
    fi
    AVAILABLE=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{print $3}')
    if echo "$AVAILABLE" | grep -q "bbr2"; then
        sysctl -w net.core.default_qdisc=fq
        sysctl -w net.ipv4.tcp_congestion_control=bbr2
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr2" >> /etc/sysctl.conf
        sysctl -p
        echo "[✓] BBR2 aktif"
    elif echo "$AVAILABLE" | grep -q "bbr"; then
        sysctl -w net.core.default_qdisc=fq
        sysctl -w net.ipv4.tcp_congestion_control=bbr
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
        echo "[✓] BBR aktif"
    else
        echo "[!] Kernel tidak support BBR/BBR2"
    fi
}
activate_bbr2

# ===========================================
# FIREWALL SAFE (UFW)
# ===========================================
read -p "Aktifkan firewall anti-DDOS? (y/n): " FW_USE
if [[ "$FW_USE" =~ ^[Yy]$ ]]; then
    apt install -y ufw
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

# ===========================================
# PHP-FPM OPTIMIZATION SAFE
# ===========================================
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
echo " Timeout proxy tinggi → minim 504 di HTTPS"
echo "================================================"
