# PERATURAN PROJEK & PEDOMAN REGISTRASI

Dokumen ini berisi aturan dan pedoman wajib untuk pengembangan dan penggunaan aplikasi ini.

## 1. KEWAJIBAN MELENGKAPI DATA PENDAFTARAN
Setiap pengguna yang ingin mendaftar (Register) ke dalam sistem **WAJIB** melengkapi seluruh data yang diminta pada formulir pendaftaran tanpa terkecuali. 

*   **Aturan Ketat:** Tombol pendaftaran tidak akan berfungsi atau sistem akan menolak permintaan jika terdapat satu saja kolom isian (field) wajib yang dikosongkan.
*   **Data Wajib Meliputi:**
    -   Foto Profil
    -   Nama Lengkap
    -   Username (unik)
    -   Password & Konfirmasi Password
    -   Status Warga (Warga Asli / Perantau)
    -   Asal Daerah & Keperluan (Khusus Perantau)
    -   Pilihan Organisasi (Daerah, Desa, Kelompok, Kelas/Caberawit)

## 2. HIERARKI ORGANISASI & KONTAK ADMIN
Sistem ini menggunakan struktur organisasi berjenjang dengan standar penamaan ketat.

### A. Standarisasi Penamaan Kategori (Level Terbawah)
Wajib menggunakan penamaan berikut untuk level Kategori/Kelas (di bawah Organisasi Kelompok), dari jenjang tertinggi ke terendah:
1.  **Kelompok** (Pengganti istilah Dewasa/Orang Tua)
2.  **Muda-mudi**
3.  **Praremaja**
4.  **Caberawit**

*Tidak diperbolehkan menggunakan nama lain untuk menjaga konsistensi data.*

### B. Jika DAERAH Tidak Tersedia
*   **Kondisi:** Pengguna membuka dropdown "Daerah" namun tidak menemukan nama daerahnya.
*   **Tindakan:** Segera hubungi **Admin Ence**.

### B. Jika DAERAH Ada, Tapi DESA Tidak Tersedia
*   **Kondisi:** Pengguna sudah memilih Daerah, tapi dropdown "Desa" kosong atau tidak ada desa tujuannya.
*   **Tindakan:** Hubungi **Admin Daerah** setempat.
*   **Fitur Sistem:** Aplikasi akan secara otomatis menampilkan daftar **Admin Daerah** di bawah dropdown. 
    *   **Klik Nama Admin:** Pengguna dapat langsung mengklik nama admin untuk **terhubung otomatis ke WhatsApp** dengan pesan keluhan yang sudah disiapkan sistem.

### C. Jika DESA Ada, Tapi KELOMPOK Tidak Tersedia
*   **Kondisi:** Pengguna sudah memilih Desa, tapi dropdown "Kelompok" kosong atau tidak ada kelompok tujuannya.
*   **Tindakan:** Hubungi **Admin Desa** setempat.
*   **Fitur Sistem:** Aplikasi akan secara otomatis menampilkan daftar **Admin Desa** di bawah dropdown.
    *   **Klik Nama Admin:** Pengguna dapat langsung mengklik nama admin untuk **terhubung otomatis ke WhatsApp** dengan pesan keluhan yang sudah disiapkan sistem.

---

## 3. HAK AKSES DAN TAMPILAN BERDASARKAN PERAN (RBAC)
Sistem membedakan tampilan dan kewenangan berdasarkan Level Admin pengguna.

### A. User Biasa (Non-Admin)
*   **Tampilan:** Hanya memiliki 3 menu navigasi utama di bawah: **Home**, **QR Code**, dan **Profil**.
*   **Menu Admin:** **TIDAK MUNCUL** sama sekali.
*   **Kewenangan:**
    *   Hanya bisa melihat data dirinya sendiri (Dashboard standar).
    *   Mengedit profil pribadi (termasuk No WA dan Foto).
    *   Menggunakan fitur umum (Scan QR, melihat pengumuman, dll).

### B. Struktur Admin (Level 1 - 4)
User dengan status Admin akan melihat tambahan menu **"Admin"** di navigasi bawah (Total 4 Menu).

**Aturan Umum Menu Admin (Organisasi, Pengajian, Presensi, Pengguna):**
Seluruh konten dalam menu Admin (Daftar Organisasi, Jadwal Pengajian, Rekap Presensi) **OTOMATIS DIFILTER** sesuai dengan kategori/level admin:
*   **Menu Organisasi:** Hanya menampilkan anak organisasi di bawah wilayah admin tersebut.
*   **Menu Pengajian:** Hanya menampilkan jadwal pengajian yang relevan dengan level organisasi admin.
*   **Menu Presensi:** Hanya menampilkan rekap kehadiran anggota di lingkup organisasi admin.

#### 1. Admin Kategori / Caberawit (Level 4)
*   **Tampilan Menu Admin:**
    *   Menu pengelolaan terbatas pada data anggota di Kategorinya.
*   **Kewenangan Organisasi:**
    *   **TIDAK BISA** menambah organisasi apapun.

#### 2. Admin Kelompok (Level 3)
*   **Lingkup:** Mengelola satu Kelompok.
*   **Kewenangan Organisasi:**
    *   Hanya bisa menambah **Kategori/Kelas** di bawah kelompoknya sendiri.
    *   **TIDAK BISA** menambah Kelompok lain. (Harus hubungi Admin Desa).

#### 3. Admin Desa (Level 2)
*   **Lingkup:** Mengelola satu Desa.
*   **Kewenangan Organisasi:**
    *   Bisa menambah **Kelompok** di bawah naungan Desa-nya.
    *   Bisa menambah **Kategori/Kelas** (melalui menu Kelompok).
    *   **TIDAK BISA MENAMBAH DESA LAIN.**
    *   *Jika ingin menambah Desa baru, WAJIB menghubungi Admin Daerah (Level 1).*

#### 4. Admin Daerah (Level 1)
*   **Lingkup:** Mengelola satu Daerah (Kabupaten/Kota).
*   **Kewenangan Organisasi:**
    *   Bisa menambah **Desa** di bawah naungan Daerah-nya.
    *   Bisa menambah **Kelompok** dan **Kategori** di bawah jalurnya.
    *   **TIDAK BISA MENAMBAH DAERAH LAIN.**
    *   *Jika ingin menambah Daerah baru, WAJIB menghubungi Super Admin.*



### C. Super Admin (Level 0)
*   **Tampilan:** Akses penuh ke seluruh fitur dan menu.
*   **Tampilan Menu Organisasi:** Melihat mulai dari level teratas (**Daftar Daerah**).
*   **Kewenangan:**
    *   **Dewa Mode:** Bisa melakukan segalanya (Create, Read, Update, Delete) di semua level.
    *   Bisa mengangkat Admin Daerah.
    *   Bisa menghapus data master yang tidak bisa dihapus admin lain.

---
**Prinsip Keamanan (Logika Sistem):**
1.  **Hierarki View:** Admin Level X hanya bisa melihat data Level X ke bawah. (Contoh: Admin Desa tidak bisa melihat data Desa tetangga, apalagi data Daerah).
2.  **Hierarki Assignment:** Admin Level X hanya bisa mengangkat user menjadi admin setara (Level X) atau di bawahnya (Level > X). Admin Desa TIDAK BISA mengangkat seseorang menjadi Admin Daerah.
