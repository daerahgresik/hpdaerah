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

## 4. SISTEM PENGELOLAAN BERDASARKAN KONTEKS ADMIN

### A. Super Admin (Level 0) - Wajib Pilih Konteks Daerah

**ATURAN UTAMA:** Super Admin **TIDAK BISA** langsung mengelola forum/pengajian tanpa memilih konteks daerah terlebih dahulu.

**Alur:**
1. Super Admin masuk ke menu Admin (Pengajian/Organisasi/Presensi)
2. Sistem menampilkan dialog/screen **"Pilih Daerah yang Ingin Dikelola"**
3. Super Admin memilih salah satu Daerah
4. Setelah memilih, Super Admin **berperan sebagai** Admin Daerah tersebut
5. Semua tampilan dan akses mengikuti aturan Admin Daerah yang dipilih
6. **Informasi jelas ditampilkan**: "Anda sedang mengelola: **[Nama Daerah]**"

**Tujuan:** Memastikan target pengajian selalu jelas dan terlockir ke jalur tertentu.

---

### B. Aturan Scope Admin (Hanya Bisa Kelola Jalur Sendiri)

#### 1. Admin Daerah (Level 1)
- **Scope:** Mengelola 1 Daerah beserta SELURUH anak-anaknya
- **Bisa Buat Pengajian Level:** Daerah, Desa, Kelompok, Kategori (sampai Caberawit)
- **TIDAK BISA:** Mengelola Daerah lain
- **Tampilan Header:** `"Admin Daerah: [Nama Daerah]"`

#### 2. Admin Desa (Level 2)
- **Scope:** Mengelola 1 Desa beserta SELURUH anak-anaknya
- **Bisa Buat Pengajian Level:** Desa, Kelompok, Kategori (sampai Caberawit)
- **TIDAK BISA:** Mengelola Desa lain atau level Daerah
- **Tampilan Header:** `"Admin Desa: [Nama Desa] • dari Daerah [Nama Daerah]"`

#### 3. Admin Kelompok (Level 3)
- **Scope:** Mengelola 1 Kelompok beserta SELURUH anak-anaknya
- **Bisa Buat Pengajian Level:** Kelompok, Kategori (sampai Caberawit)
- **TIDAK BISA:** Mengelola Kelompok lain atau level di atasnya
- **Tampilan Header:** `"Admin Kelompok: [Nama Kelompok] • Desa [Nama Desa] • Daerah [Nama Daerah]"`

#### 4. Admin Kategori (Level 4)
- **Scope:** Mengelola 1 Kategori saja
- **Bisa Buat Pengajian Level:** Hanya Kategori-nya saja
- **TIDAK BISA:** Mengelola Kategori lain atau level di atasnya
- **Tampilan Header:** `"Admin [Nama Kategori] • Kelompok [X] • Desa [Y] • Daerah [Z]"`

---

### C. Tampilan Menu Pengajian Berdasarkan Level Admin

Menu buat pengajian harus menampilkan:
1. **Header Identitas Admin** (siapa dia, dari mana jalurnya)
2. **Pilihan Level Pengajian** yang sesuai dengan scope admin
3. **Tree Navigator** untuk memilih target spesifik dalam scope-nya

**Contoh UI untuk Admin Desa:**
```
┌─────────────────────────────────────────────┐
│ 👤 Anda adalah Admin Desa                   │
│ 📍 Desa: Kuwu                               │
│ 📍 Dari Daerah: Gresik                      │
├─────────────────────────────────────────────┤
│ Pilih Level Pengajian:                      │
│ ○ Desa (Semua warga Desa Kuwu)              │
│ ○ Kelompok (Pilih kelompok...)              │
│ ○ Kategori (Pilih kelas...)                 │
└─────────────────────────────────────────────┘
```

---

## 5. SISTEM QR CODE BERBASIS PENGAJIAN

### A. Perubahan Paradigma QR Code

| Sistem Lama (SALAH) | Sistem Baru (BENAR) |
|---------------------|---------------------|
| QR Code per User (permanen) | QR Code per Pengajian (sementara) |
| Semua user punya QR | Hanya target pengajian yang dapat QR |
| QR bisa dipakai berulang | QR sekali pakai |
| QR sama untuk semua event | QR unik per user per pengajian |

---

### B. Alur Generate QR Code

1. **Admin membuat Pengajian** dan menentukan:
   - Level pengajian (Daerah/Desa/Kelompok/Kategori)
   - Target spesifik (organisasi mana)
   - Waktu, lokasi, deskripsi, dll

2. **Admin klik "Konfirmasi Buat Pengajian"**

3. **Sistem otomatis:**
   - Mengidentifikasi SEMUA user yang menjadi target (berdasarkan org_id)
   - Generate QR Code UNIK untuk setiap user target
   - Simpan ke tabel `pengajian_qr`
   - Push notification ke user target (opsional)

4. **User target:**
   - Membuka menu "QR Code"
   - Melihat QR Code aktif untuk pengajian yang ditugaskan
   - Melihat informasi lengkap pengajian

---

### C. Tampilan Menu QR Code untuk User

#### Kondisi 1: Tidak Ada Pengajian Aktif
```
┌─────────────────────────────────────────────┐
│              📭 TIDAK ADA PENGAJIAN         │
│                                             │
│  Saat ini Anda tidak memiliki              │
│  tugas pengajian yang harus dihadiri.      │
│                                             │
│  Hubungi admin jika ada pertanyaan.        │
└─────────────────────────────────────────────┘
```

#### Kondisi 2: Ada Pengajian Aktif (QR Belum Dipakai)
```
┌─────────────────────────────────────────────┐
│         📋 PENGAJIAN AKTIF                  │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │         [QR CODE IMAGE]              │   │
│  │         (Unik untuk Anda)            │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  📌 Pengajian Rutin Minggu Ini             │
│  📍 Masjid Al-Ikhlas, Kuwu                 │
│  📅 Minggu, 26 Jan 2026 • 08:00 WIB        │
│  👥 Target: Muda-mudi                       │
│                                             │
│  ⚠️ Tunjukkan QR ini ke Admin saat hadir   │
│  ⚠️ QR hanya bisa digunakan SEKALI          │
└─────────────────────────────────────────────┘
```

#### Kondisi 3: QR Sudah Dipakai (Sudah Presensi)
```
┌─────────────────────────────────────────────┐
│         ✅ PRESENSI BERHASIL                │
│                                             │
│  Anda telah hadir di pengajian:            │
│  📌 Pengajian Rutin Minggu Ini             │
│  📍 Masjid Al-Ikhlas, Kuwu                 │
│  ⏰ Hadir pada: 08:15 WIB                   │
│                                             │
│  🎉 Semoga berkah dan bermanfaat!          │
└─────────────────────────────────────────────┘
```

---

### D. Aturan QR Code

1. **UNIK:** Setiap QR Code berbeda untuk setiap kombinasi (user + pengajian)
2. **SEKALI PAKAI:** Setelah di-scan, QR tidak bisa dipakai lagi (is_used = true)
3. **TERBATAS WAKTU:** QR hanya valid selama pengajian berlangsung
4. **TARGET SAJA:** Hanya user yang masuk dalam target audience yang mendapat QR
5. **INFORMATIF:** QR selalu disertai info lengkap (apa, kapan, di mana)

---

### E. Tabel Database `pengajian_qr`

```sql
CREATE TABLE pengajian_qr (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pengajian_id UUID REFERENCES pengajian(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  qr_code TEXT UNIQUE NOT NULL,  -- Hash unik
  is_used BOOLEAN DEFAULT false,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(pengajian_id, user_id)  -- 1 user = 1 QR per pengajian
);
```

---

## 6. PRINSIP KEAMANAN (LOGIKA SISTEM)

1. **Hierarki View:** Admin Level X hanya bisa melihat data Level X ke bawah. (Contoh: Admin Desa tidak bisa melihat data Desa tetangga, apalagi data Daerah).

2. **Hierarki Assignment:** Admin Level X hanya bisa mengangkat user menjadi admin setara (Level X) atau di bawahnya (Level > X). Admin Desa TIDAK BISA mengangkat seseorang menjadi Admin Daerah.

3. **Konteks Terkunci:** Super Admin harus memilih konteks daerah sebelum bisa mengelola apapun, memastikan scope selalu jelas.

4. **QR Sekali Pakai:** Mencegah penyalahgunaan (titip absen, share QR, dll).

5. **Target Spesifik:** Pengajian selalu punya target yang jelas, QR hanya untuk target tersebut.

---

## 7. VERIFIKASI PRESENSI & KEAMANAN LANJUTAN

### A. Verifikasi Identitas (Anti-Fraud)
Setiap kali Admin melakukan scan QR Code, sistem **WAJIB** menampilkan dialog verifikasi yang berisi:
1.  **Foto Profil asli** pengguna.
2.  **Nama Lengkap**.
3.  **Detail Organisasi** (Kelompok, Desa, Daerah).

**Tindakan Admin:**
*   **Terima (Hadir):** Jika data sesuai dengan orang yang membawa perangkat.
*   **Tolak (Bukan Dia):** Jika pemegang akun berbeda. Status pengguna tersebut langsung dicatat sebagai **"Tidak Hadir"**. Pengguna asli harus menggunakan akun pribadinya sendiri untuk mendapatkan kode yang valid.

### B. Otomatisasi Status "Alpha" (Tidak Hadir)
*   Fitur "Hapus Room" di Menu Aktif kini berfungsi sebagai fungsi **Penutupan Room**.
*   Saat Room ditutup, sistem secara otomatis:
    1.  Mencari semua target pengguna yang **belum** melakukan presensi (is_used = false).
    2.  Mencatat mereka sebagai **"Tidak Hadir"** di rekap presensi.
    3.  Tandai QR agar hangus dari peranti pengguna tersebut.
*   User akan melihat status **"Tercatat Tidak Menghadiri"** pada menu QR Code mereka untuk pengajian tersebut.

---

## 8. PRESENSI CENTER & REKAPITULASI

### A. Tampilan Berbasis Scope
Daftar hadir pada Presensi Center menampilkan seluruh target pengguna yang seharusnya hadir (bukan hanya yang sudah hadir). Daftar ini difilter ketat berdasarkan level Admin:
*   **Admin Kelompok:** Hanya melihat anggota kelompoknya.
*   **Admin Desa:** Melihat seluruh anggota di kelompok-kelompok naungan desanya.
*   **Admin Daerah:** Melihat seluruh anggota di wilayah daerahnya.

### B. Kontrol Manual Admin
Selain melalui Scan QR, Admin memiliki otoritas manual untuk mengubah status anggota yang BELUM absen:
1.  **Centang (Hadir):** Mencatat kehadiran manual.
2.  **Izin:** Mencatat izin (wajib mengisi alasan/keterangan).
3.  **Alpha (Silang):** Memaksa status menjadi tidak hadir.

*Setiap tindakan manual Admin akan mencatat `approved_by` dan metode `manual_admin` untuk audit.*

---

## 9. ATURAN MEDIA & PENYIMPANAN

### A. Kompresi Foto Profil (Smart Compression)
- **Aturan:** Setiap foto profil yang diunggah saat pendaftaran atau pembaruan profil **WAJIB** dikompresi secara otomatis oleh sistem.
- **Batas Ukuran:** Maksimal ukuran file adalah **200 KB**.
- **Tujuan:** Efisiensi storage Supabase, penghematan kuota pengguna, dan kecepatan loading daftar hadir/profil.
- **Logika:** Sistem akan mendeteksi ukuran file, jika melebihi batas, maka kualitas dan dimensi akan diturunkan secara cerdas hingga di bawah 200 KB tanpa menghilangkan identitas visual.

### B. Bukti Foto Izin (Real-time Evidence)
- **Aturan:** Foto bukti untuk keperluan izin (Sakit, Kerja, dll) **WAJIB** diambil menggunakan kamera langsung melalui aplikasi.
- **Larangan:** Tidak diperkenankan mengambil foto dari galeri/memori perangkat untuk mencegah manipulasi bukti atau penggunaan foto lama.
- **Tujuan:** Menjamin keabsahan kehadiran dan alasan yang disampaikan pada saat kejadian berlangsung.
