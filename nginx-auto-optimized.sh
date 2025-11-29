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
# SETTING BERDASARKAN PROFIL
# ===========================================
if [[ "$OPT" == "1" ]]; then
    WORKER_CONN=2048
    MAX_CHILD=10
    PM_START=2
    PM_MIN=2
    PM_MAX=4
    GZIP_LEVEL=4
elif [[ "$OPT" == "2" ]]; then
    WORKER_CONN=4096
    MAX_CHILD=25
    PM_START=5
    PM_MIN=5
    PM_MAX=10
    GZIP_LEVEL=5
elif [[ "$OPT" == "3" ]]; then
    WORKER_CONN=8192
    MAX_CHILD=50
    PM_START=10
    PM_MIN=10
    PM_MAX=20
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
# TULIS CONFIG NGINX OPTIMIZED
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
    keepalive_timeout 30;

    gzip on;
    gzip_comp_level $GZIP_LEVEL;

    client_max_body_size 100M;

    include /etc/nginx/mime.types;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# ===========================================
# TANYA USER: MAU SSL ATAU TIDAK
# ===========================================
read -p "Apakah anda ingin menginstall SSL Let's Encrypt? (y/n): " SSL_USE

if [[ "$SSL_USE" =~ ^[Yy]$ ]]; then
    read -p "Masukkan domain SSL (contoh: panel.hendri.site): " DOMAIN
    read -p "Masukkan email untuk SSL: " EMAIL

    apt install -y certbot python3-certbot-nginx

    certbot --nginx -d $DOMAIN --email $EMAIL --non-interactive --agree-tos

    echo "[+] SSL berhasil diaktifkan untuk $DOMAIN"
else
    echo "[+] SSL dilewati..."
fi

# ===========================================
# TANYA USER: MAU BBR ATAU TIDAK
# ===========================================
read -p "Aktifkan BBR2 Accelerator? (y/n): " BBR_USE

if [[ "$BBR_USE" =~ ^[Yy]$ ]]; then
    echo "[+] Mengaktifkan BBR2..."

    cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl -p

    echo "[+] BBR2 aktif!"
else
    echo "[+] BBR2 dilewati..."
fi

# ===========================================
# TANYA USER: MAU FIREWALL ANTI-DDOS ATAU TIDAK
# ===========================================
read -p "Aktifkan firewall anti-DDoS (ufw rate limit)? (y/n): " FW_USE

if [[ "$FW_USE" =~ ^[Yy]$ ]]; then
    echo "[+] Mengaktifkan UFW Anti-DDoS..."

    apt install -y ufw

    ufw allow OpenSSH
    ufw allow 80/tcp
    ufw allow 443/tcp

    ufw limit 80/tcp
    ufw limit 443/tcp

    echo "y" | ufw enable

    echo "[+] Firewall aktif!"
else
    echo "[+] Firewall dilewati..."
fi

# ===========================================
# PHP-FPM OPTIMISASI OTOMATIS (JIKA ADA)
# ===========================================
PHP_FPM=$(ls /etc/php/*/fpm/pool.d/www.conf 2>/dev/null || true)

if [[ -n "$PHP_FPM" ]]; then
    sed -i "s/^pm.max_children =.*/pm.max_children = $MAX_CHILD/" "$PHP_FPM"
    sed -i "s/^pm.start_servers =.*/pm.start_servers = $PM_START/" "$PHP_FPM"
    sed -i "s/^pm.min_spare_servers =.*/pm.min_spare_servers = $PM_MIN/" "$PHP_FPM"
    sed -i "s/^pm.max_spare_servers =.*/pm.max_spare_servers = $PM_MAX/" "$PHP_FPM"

    systemctl restart php*-fpm
fi

systemctl restart nginx

echo ""
echo "================================================"
echo " INSTALASI SELESAI!"
echo " Fitur tambahan hanya dipasang jika anda pilih"
echo "================================================"
