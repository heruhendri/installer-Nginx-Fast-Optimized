# **installer otomatis** yang bisa memilih **profil optimasi server berdasarkan RAM & CPU**:

* **1 GB RAM – 1 CPU (VPS kecil / NATVPS)**
* **2–4 GB RAM – 2 CPU (menengah)**
* **8–10 GB RAM – 4–8 CPU (besar)**

Installer ini akan:
* ✔ Optimasi Nginx berdasarkan kapasitas server
* ✔ Optimasi PHP-FPM sesuai profil RAM
* ✔ Optimasi kernel & network (BBR optional)
* ✔ Auto-detect PHP-FPM bila ada
* ✔ Auto-backup config sebelum edit

---
## **🖼️ SCREENSHOOT**
![https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/fedc44236c4746601653fd60f8e59d14e9ca74a3/ss.png](https://)

# ✅ **INSTALLER NGINX AUTO-OPTIMIZED BERDASARKAN RAM/CPU**

### **Berikut contoh **link installer dengan bash + curl** seperti yang biasa dipakai untuk auto-install:**

---


GitHub Script file:

```
https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/nginx-auto-optimized.sh
```

Maka cara memanggil installernya:

### **1️⃣ Menggunakan curl**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/nginx-auto-optimized.sh)
```

### **2️⃣ Menggunakan wget**

```bash
bash <(wget -qO- https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/nginx-auto-optimized.sh)
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
# 📌 *Jika VPS Anda Sudah Terinstall Genieacs Node Dll Disarankan Menggunakan Script ke 2*

Berikut **versi script Anda yang sudah saya perbaiki**, **TIDAK merusak server GenieACS**, dan **TIDAK menyebabkan error BBR2** di NAT VPS / LXC.

### 🔧 PERBAIKAN YANG DILAKUKAN

* ✔ **BBR2 tidak error lagi** → pengecekan diperketat
* ✔ **Tidak menyentuh sysctl** jika NAT VPS / LXC
* ✔ **Restart PHP-FPM aman** (tidak error walau PHP tidak terinstal)
* ✔ **Restart NGINX aman**
* ✔ **Konfigurasi tidak merusak port GenieACS (3000,7547,7557,7567)**
* ✔ **Tidak mengubah firewall port GenieACS**

---

GitHub Script file:

```
https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/safe-nginx.sh
```

Maka cara memanggil installernya:

### **1️⃣ Menggunakan curl**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/safe-nginx.sh)
```

### **2️⃣ Menggunakan wget**

```bash
bash <(wget -qO- https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/safe-nginx.sh)
```

---

### jangan Lupa ⭐ Jika Repo Ini Bermanfaat

Contact:
* Mail heruu2004@gmail.com
* Telegram https://t.me/GbtTapiPngnSndiri