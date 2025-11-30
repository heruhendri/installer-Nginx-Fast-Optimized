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
![](https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/fedc44236c4746601653fd60f8e59d14e9ca74a3/ss.png)
-

# 1️⃣ **Script 1 — “FULL FIXED”**

* **Profil VPS dipilih manual** (1/2/3).
* Parameter NGINX & PHP-FPM **hardcoded sesuai profil**:

* Worker connections, PHP-FPM max_children, start_servers, min/max spare servers, gzip level.
* SSL opsional dengan **Let's Encrypt**.
* BBR/BBR2 bisa diaktifkan **manual dengan timeout 10s**.
* Firewall UFW dengan port GenieACS dibuka **dengan limit 80/443**.
* **Fokus:** Installer fixed, cocok untuk GenieACS, mengurangi 504, optimasi aman untuk profil yang ditentukan.

**Kelemahan / batasan:**

* Tidak adaptif → harus pilih profil.
* Tidak otomatis menyesuaikan dengan RAM/CPU VPS yang sebenarnya.

---

### **1️⃣ Menggunakan curl**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/nginx-auto-optimized.sh)
```

### **2️⃣ Menggunakan wget**

```bash
bash <(wget -qO- https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/nginx-auto-optimized.sh)
```

Setelah jalan, pilih:

* **1** untuk VPS kecil
* **2** untuk VPS sedang
* **3** untuk VPS besar

---
# 📌 **Script 2 — “SMART RESOURCE ADAPT”**

* **Tidak perlu pilih profil** → script **mendeteksi CPU & RAM VPS otomatis**.
* Parameter NGINX & PHP-FPM **ditentukan otomatis berdasarkan RAM**:

  * <2GB → Kecil
  * 2–8GB → Medium
  * > 8GB → Besar
* Semua pengaturan worker_connections & PHP-FPM diadaptasi sesuai hardware.
* SSL, BBR/BBR2, firewall sama seperti Script 1.
* **Fokus:** Lebih cerdas / adaptif, minim 504 walaupun user tidak memilih profil manual.

**Kelebihan:**

* Lebih fleksibel → tidak perlu pengetahuan profil VPS.
* Optimal untuk berbagai ukuran VPS, otomatis menyesuaikan resource.
---
### **1️⃣ Menggunakan curl**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/optimized-auto.sh)
```

### **2️⃣ Menggunakan wget**

```bash
bash <(wget -qO- https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/optimized-auto.sh)
```

---

## 3️⃣ **Script 3 — “MODULAR FEATURES”**

* Masih **memilih profil manual** (1/2/3).
* Parameter NGINX & PHP-FPM **lebih tinggi dibanding Script 1** → lebih agresif:

  * Worker connections & max_children hampir **2x lipat dibanding Script 1**.
* Client max body size **lebih kecil (100M vs 200M)**.
* Keepalive timeout & requests lebih kecil → fokus **mengurangi memory footprint**.
* SSL, BBR/BBR2, firewall tetap opsional.
* Lebih modular, kata-katanya “Fitur tambahan dipasang sesuai pilihan Anda”.
* **Fokus:** Installer lebih modular, bisa digunakan untuk berbagai layanan, bukan hanya GenieACS.

**Kelebihan / karakteristik:**

* Lebih agresif dalam resource allocation → cocok VPS besar / high load.
* Modular → lebih mudah menambahkan fitur tambahan lain.
* Cocok jika ingin menyesuaikan sendiri fitur firewall / SSL / BBR2.

---
### **1️⃣ Menggunakan curl**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/safe-nginx.sh)
```

### **2️⃣ Menggunakan wget**

```bash
bash <(wget -qO- https://raw.githubusercontent.com/heruhendri/installer-Nginx-Fast-Optimized/main/safe-nginx.sh)
```
### Jangan Lupa ⭐ Jika Repo Ini Bermanfaat

### **Ringkasan Perbandingan**

| Fitur / Script       | Script 1 (Full Fixed)          | Script 2 (Smart Adapt)  | Script 3 (Modular Features) |
| -------------------- | ------------------------------ | ----------------------- | --------------------------- |
| Profil manual        | Ya (1/2/3)                     | Tidak, auto             | Ya (1/2/3)                  |
| Deteksi RAM/CPU VPS  | Tidak                          | Ya                      | Tidak                       |
| Worker_connections   | 1024–4096                      | Disesuaikan otomatis    | 2048–8192 (lebih tinggi)    |
| PHP-FPM max_children | 5–20                           | Disesuaikan otomatis    | 10–50 (lebih tinggi)        |
| Client max body size | 200M                           | 200M                    | 100M                        |
| Keepalive timeout    | 65                             | 65                      | 30                          |
| Gzip level           | 4–6                            | 5                       | 4–6                         |
| SSL                  | Opsional                       | Opsional                | Opsional                    |
| BBR/BBR2             | Opsional                       | Opsional                | Opsional                    |
| Firewall UFW         | Opsional, dengan port GenieACS | Opsional, port GenieACS | Opsional, port GenieACS     |
| Fokus utama          | GenieACS fixed                 | GenieACS adaptif        | Modular & fleksibel         |

---

✅ **Intinya:**

* Script 1: stabil, profil fixed, aman untuk GenieACS, manual pilih profil.
* Script 2: otomatis adaptif, sesuaikan hardware VPS → lebih cerdas.
* Script 3: agresif & modular, manual pilih profil, cocok untuk VPS besar / high load / kebutuhan multi-service.

---
Contact:
* Mail heruu2004@gmail.com
* Telegram https://t.me/GbtTapiPngnSndiri