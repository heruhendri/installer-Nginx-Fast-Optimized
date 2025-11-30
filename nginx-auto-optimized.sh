#!/bin/bash
set -euo pipefail

echo "================================================"
echo "  NGINX AUTO INSTALLER (FULL FIXED) BY HENDRI"
echo "================================================"
echo ""
echo "Pilih profile optimasi server:"
echo "1) VPS Kecil     (1GB RAM - 1 CPU)"
echo "2) VPS Medium    (2-4GB RAM - 2 CPU)"
echo "3) VPS Besar     (8-10GB RAM - 4+ CPU)"
echo ""

read -p "Masukkan pilihan (1/2/3): " OPT

# ===========================================
# PROFIL OPTIMASI
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
# INSTALL NGINX & DEPENDENSI
# ===========================================
apt update
apt install -y nginx certbot python3-certbot-nginx ufw

echo "[+] Backup nginx.conf lama..."
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%s)

# ===========================================
# NGINX CONFIG OPTIMIZED
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
# GENIEACS REVERSE PROXY (MINIM 504)
# ===========================================
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

# ===========================================
# SSL LET'S ENCRYPT OPTIONAL
# ===========================================
read -p "Install SSL Let's Encrypt? (y/n): " SSL_USE
if [[ "$SSL_USE" =~ ^[Yy]$ ]]; then
    read -p "Domain SSL: " DOMAIN
    read -p "Email: " EMAIL

    certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
    echo "[+] SSL aktif untuk $DOMAIN"
else
    echo "[+] SSL dilewati..."
fi

# ===========================================
# BBR/BBR2 SAFE
# ===========================================
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
        echo "[+] Mengaktifkan BBR2..."
        sysctl -w net.core.default_qdisc=fq 2>/dev/null || true
        sysctl -w net.ipv4.tcp_congestion_control=bbr2 2>/dev/null || true
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr2" >> /etc/sysctl.conf
        sysctl -p 2>/dev/null || true
        echo "[✓] BBR2 aktif."
        return
    elif echo "$AVAILABLE" | grep -q "bbr"; then
        echo "[+] Kernel mendukung BBR. Mengaktifkan BBR..."
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

# ===========================================
# FIREWALL UFW SAFE
# ===========================================
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

# ===========================================
# PHP-FPM OPTIMIZATION (SAFE)
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
echo " Proxy timeout tinggi → minim 504 di HTTPS"
echo "================================================"
