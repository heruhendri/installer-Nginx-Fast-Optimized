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

    client_max_body_size 100M;

    keepalive_timeout 30;
    keepalive_requests 200;

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
# SSL OPTIONAL
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
# FUNGSI BBR2
# ===========================================
activate_bbr2() {
    echo -n "[?] Mengaktifkan BBR2 Accelerator? (y/n): "
    read ans
    if [[ $ans != "y" ]]; then
        echo "[!] BBR2 dibatalkan."
        return
    fi

    echo "[+] Mengecek dukungan kernel..."

    # Jika folder sysctl tidak ada → NAT VPS / LXC
    if [[ ! -d /proc/sys/net/ipv4 ]]; then
        echo "[!] Kernel tidak bisa diubah (LXC/NAT VPS)."
        echo "[!] BBR/BBR2 tidak dapat diaktifkan."
        return
    fi

    # Ambil daftar CC
    AVAILABLE=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{print $3}')

    # Jika BBR2 tersedia
    if echo "$AVAILABLE" | grep -q "bbr2"; then
        echo "[+] Mengaktifkan BBR2..."
        sysctl -w net.core.default_qdisc=fq
        sysctl -w net.ipv4.tcp_congestion_control=bbr2
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr2" >> /etc/sysctl.conf
        sysctl -p
        echo "[✓] BBR2 berhasil diaktifkan."
        return
    fi

    # Jika hanya BBR tersedia
    if echo "$AVAILABLE" | grep -q "bbr"; then
        echo "[+] Kernel mendukung BBR. Mengaktifkan BBR..."
        sysctl -w net.core.default_qdisc=fq
        sysctl -w net.ipv4.tcp_congestion_control=bbr
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
        echo "[✓] BBR berhasil diaktifkan."
        return
    fi

    echo "[!] Kernel tidak mendukung BBR/BBR2."
}

# ====== PANGGIL FUNGSI BBR ======
activate_bbr2

# ===========================================
# FIREWALL OPTIONAL
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
# PHP-FPM OPTIMISASI (Jika Ada)
# ===========================================
for PHPV in /etc/php/*/fpm/pool.d/www.conf; do
    if [[ -f "$PHPV" ]]; then
        sed -i "s/^pm.max_children =.*/pm.max_children = $MAX_CHILD/" "$PHPV"
        sed -i "s/^pm.start_servers =.*/pm.start_servers = $PM_START/" "$PHPV"
        sed -i "s/^pm.min_spare_servers =.*/pm.min_spare_servers = $PM_MIN/" "$PHPV"
        sed -i "s/^pm.max_spare_servers =.*/pm.max_spare_servers = $PM_MAX/" "$PHPV"
    fi
done

systemctl restart nginx
systemctl restart php*-fpm 2>/dev/null || true

echo ""
echo "================================================"
echo " INSTALASI SELESAI!"
echo " Fitur tambahan dipasang sesuai pilihan Anda."
echo "================================================"
