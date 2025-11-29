#!/bin/bash
set -euo pipefail

echo "==============================================="
echo "  SAFE NGINX INSTALLER (For GenieACS) by Hendri"
echo "==============================================="
echo ""

# ===========================================
# INSTALL NGINX
# ===========================================
apt update
apt install -y nginx

echo "[+] NGINX terinstall (AMAN, tanpa overwrite config)."

# ===========================================
# TUNING AMAN (TIDAK MENYENTUH nginx.conf)
# ===========================================
cat > /etc/nginx/conf.d/performance.conf << EOF
##
## NGINX PERFORMANCE TUNING (AMANKAN GENIEACS)
##

# Worker tuning
worker_processes auto;
worker_rlimit_nofile 200000;

events {
    worker_connections 4096;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    server_tokens off;

    keepalive_timeout 30;
    keepalive_requests 200;

    client_max_body_size 100M;

    gzip on;
    gzip_min_length 10240;
    gzip_comp_level 5;
    gzip_vary on;
    gzip_proxied any;

    # Extra optimisation
    types_hash_max_size 2048;
    server_names_hash_bucket_size 128;
}
EOF

echo "[+] Performance tuning ditambahkan ke /etc/nginx/conf.d/performance.conf"

# ===========================================
# OPSIONAL SSL
# ===========================================
read -p "Install SSL Let's Encrypt? (y/n): " SSL

if [[ "$SSL" =~ ^[Yy]$ ]]; then
    read -p "Masukkan domain SSL: " DOMAIN
    read -p "Masukkan email: " EMAIL

    apt install -y certbot python3-certbot-nginx

    certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

    echo "[✓] SSL aktif untuk $DOMAIN"
else
    echo "[-] SSL dilewati"
fi

# ===========================================
# OPSIONAL: BBR2
# ===========================================
read -p "Aktifkan BBR2 Accelerator (y/n): " BBR

if [[ "$BBR" =~ ^[Yy]$ ]]; then

    if [[ ! -d /proc/sys/net/ipv4 ]]; then
        echo "[!] Sistem ini LXC/NAT VPS → tidak bisa enable BBR"
    else
        AVAILABLE=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{print $3}')

        if echo "$AVAILABLE" | grep -q "bbr2"; then
            echo "[+] Mengaktifkan BBR2..."
            sysctl -w net.core.default_qdisc=fq
            sysctl -w net.ipv4.tcp_congestion_control=bbr2
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr2" >> /etc/sysctl.conf
            sysctl -p
            echo "[✓] BBR2 aktif."
        elif echo "$AVAILABLE" | grep -q "bbr"; then
            echo "[+] Kernel tidak ada BBR2, menggunakan BBR..."
            sysctl -w net.core.default_qdisc=fq
            sysctl -w net.ipv4.tcp_congestion_control=bbr
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p
            echo "[✓] BBR aktif."
        else
            echo "[!] Kernel tidak mendukung BBR/BBR2."
        fi
    fi
else
    echo "[-] BBR2 dilewati"
fi

# ===========================================
# OPSIONAL FIREWALL (AMAN UNTUK GENIEACS)
# ===========================================
read -p "Aktifkan firewall UFW Anti-DDoS? (y/n): " FW

if [[ "$FW" =~ ^[Yy]$ ]]; then
    apt install -y ufw

    echo "[+] Mengizinkan port NGINX"
    ufw allow 80/tcp
    ufw allow 443/tcp

    echo "[+] Mengizinkan port GenieACS"
    ufw allow 3000/tcp    # UI
    ufw allow 7547/tcp    # CWMP
    ufw allow 7557/tcp    # NBI
    ufw allow 7567/tcp    # FS

    echo "[+] Mengaktifkan rate limit untuk NGINX"
    ufw limit 80/tcp
    ufw limit 443/tcp

    echo "y" | ufw enable
    echo "[✓] Firewall aktif aman!"
else
    echo "[-] Firewall dilewati"
fi

systemctl restart nginx

echo ""
echo "==============================================="
echo " INSTALASI SELESAI!"
echo " NGINX aman untuk GenieACS & multi-instance."
echo "==============================================="
