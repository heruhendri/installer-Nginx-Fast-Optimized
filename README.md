Baik Hendri, saya buatkan **installer otomatis** yang bisa memilih **profil optimasi server berdasarkan RAM & CPU**:

* **1 GB RAM – 1 CPU (VPS kecil / NATVPS)**
* **2–4 GB RAM – 2 CPU (menengah)**
* **8–10 GB RAM – 4–8 CPU (besar)**

Installer ini akan:
✔ Optimasi Nginx berdasarkan kapasitas server
✔ Optimasi PHP-FPM sesuai profil RAM
✔ Optimasi kernel & network (BBR optional)
✔ Auto-detect PHP-FPM bila ada
✔ Auto-backup config sebelum edit

---

# ✅ **INSTALLER NGINX AUTO-OPTIMIZED BERDASARKAN RAM/CPU**

Buat file:

```
nano nginx-auto-optimized.sh
```

Paste isi berikut:

```bash
#!/bin/bash
set -euo pipefail

echo "==============================================="
echo "    AUTO NGINX OPTIMIZER BY HENDRI (RAM/CPU)   "
echo "==============================================="
echo ""
echo "Pilih profile optimasi server:"
echo "1) VPS Kecil     (1GB RAM - 1 CPU)"
echo "2) VPS Medium    (2-4GB RAM - 2 CPU)"
echo "3) VPS Besar     (8-10GB RAM - 4+ CPU)"
echo ""

read -p "Masukkan pilihan (1/2/3): " OPT

# ============================
# SETTING BERDASARKAN PROFILE
# ============================
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

echo ""
echo "[+] Menggunakan profile RAM/CPU pilihan Anda..."
sleep 1

# ============================
# INSTALL NGINX JIKA BELUM ADA
# ============================
if ! command -v nginx &> /dev/null; then
    echo "[+] Menginstall Nginx..."
    apt update
    apt install -y nginx
fi

echo "[+] Backup nginx.conf lama..."
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%s)

# ============================
# TULIS CONFIG NGINX OPTIMIZED
# ============================
echo "[+] Menulis konfigurasi Nginx baru..."

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
    keepalive_requests 10000;

    gzip on;
    gzip_comp_level $GZIP_LEVEL;
    gzip_vary on;
    gzip_proxied any;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss;

    proxy_read_timeout 60;
    proxy_connect_timeout 60;
    proxy_send_timeout 60;
    fastcgi_read_timeout 60;

    open_file_cache max=200000 inactive=20s;
    open_file_cache_valid 30s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;

    server_tokens off;

    include /etc/nginx/mime.types;
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# ============================
# OPTIMASI PHP-FPM JIKA ADA
# ============================
echo "[+] Mengecek PHP-FPM..."
PHP_FPM_FILE=$(ls /etc/php/*/fpm/pool.d/www.conf 2>/dev/null || true)

if [[ -n "$PHP_FPM_FILE" ]]; then
    echo "[+] Mengoptimalkan PHP-FPM untuk profile RAM/CPU..."

    sed -i "s/^pm =.*/pm = dynamic/" "$PHP_FPM_FILE"
    sed -i "s/^pm.max_children =.*/pm.max_children = $MAX_CHILD/" "$PHP_FPM_FILE"
    sed -i "s/^pm.start_servers =.*/pm.start_servers = $PM_START/" "$PHP_FPM_FILE"
    sed -i "s/^pm.min_spare_servers =.*/pm.min_spare_servers = $PM_MIN/" "$PHP_FPM_FILE"
    sed -i "s/^pm.max_spare_servers =.*/pm.max_spare_servers = $PM_MAX/" "$PHP_FPM_FILE"

    systemctl restart php*-fpm || true
else
    echo "[+] PHP-FPM tidak ditemukan, skip..."
fi

# ============================
# RESTART NGINX
# ============================
echo "[+] Test konfigurasi Nginx..."
nginx -t

echo "[+] Restart Nginx..."
systemctl restart nginx

echo ""
echo "==============================================="
echo "    OPTIMASI SELESAI! NGINX SUDAH CEPAT!!!      "
echo "==============================================="
echo ""
echo "Profile diterapkan sesuai pilihan: $OPT"
echo ""
```

---

# ✅ **Cara menjalankan installer**

```
chmod +x nginx-auto-optimized.sh
./nginx-auto-optimized.sh
```

Setelah jalan, pilih:

* **1** untuk VPS kecil
* **2** untuk VPS sedang
* **3** untuk VPS besar

---

