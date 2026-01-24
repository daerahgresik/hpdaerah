# 📋 Dokumentasi Lengkap: Sistem Multi-Tenant Presensi Pengajian (Flutter)

> **Tanggal:** 23 Januari 2026  
> **Project:** Presensi Generus - Multi-Tenant dengan Hierarki  
> **Tech Stack:** Flutter, Supabase, Dart

---

## DAFTAR ISI

1. [Struktur Folder Flutter](#1-struktur-folder-flutter)
2. [Struktur Hierarki 4 Level](#2-struktur-hierarki-4-level)
3. [Aturan Pengajian](#3-aturan-pengajian)
4. [Aturan Admin](#4-aturan-admin)
5. [Sistem Presensi QR Hybrid](#5-sistem-presensi-qr-hybrid)
6. [Database Schema](#6-database-schema)
7. [API Endpoints](#7-api-endpoints)
8. [Fitur Aplikasi](#8-fitur-aplikasi)
9. [Menu Dinamis](#9-menu-dinamis)
10. [Alur Implementasi](#10-alur-implementasi)

---

## 1. STRUKTUR FOLDER FLUTTER

```
📁 lib/
├── 📁 models/                    # Data models
│   ├── user_model.dart
│   ├── organization_model.dart
│   ├── pengajian_model.dart
│   ├── presensi_model.dart
│   └── qr_model.dart
│
├── 📁 controllers/               # Business logic (GetX/Provider)
│   ├── auth_controller.dart
│   ├── organization_controller.dart
│   ├── pengajian_controller.dart
│   └── presensi_controller.dart
│
├── 📁 services/                  # API & External services
│   ├── supabase_service.dart
│   ├── auth_service.dart
│   ├── organization_service.dart
│   ├── pengajian_service.dart
│   └── presensi_service.dart
│
├── 📁 views/                      # UI Pages (MVC - View)
│   ├── landing_page.dart          # Halaman depan
│   ├── 📁 auth/
│   │   ├── login_page.dart
│   │   └── register_page.dart
│   │
│   ├── 📁 user/                  # Halaman user biasa
│   │   ├── dashboard_page.dart
│   │   ├── qr_page.dart
│   │   ├── izin_page.dart
│   │   ├── riwayat_page.dart
│   │   └── profil_page.dart
│   │
│   └── 📁 admin/                 # Halaman admin
│       ├── admin_dashboard_page.dart
│       ├── 📁 organisasi/
│       │   ├── organisasi_list_page.dart
│       │   ├── organisasi_detail_page.dart
│       │   └── organisasi_form_page.dart
│       ├── 📁 pengajian/
│       │   ├── pengajian_list_page.dart
│       │   ├── pengajian_form_page.dart
│       │   ├── scan_qr_page.dart
│       │   ├── manual_approve_page.dart
│       │   └── kelola_izin_page.dart
│       ├── 📁 pengguna/
│       │   └── pengguna_list_page.dart
│       └── 📁 rekap/
│           └── rekap_page.dart
│
├── 📁 widgets/                   # Reusable widgets
│   ├── 📁 common/
│   │   ├── custom_button.dart
│   │   ├── custom_input.dart
│   │   ├── custom_card.dart
│   │   └── loading_widget.dart
│   ├── 📁 org/
│   │   ├── org_tree_widget.dart
│   │   └── org_card_widget.dart
│   ├── 📁 pengajian/
│   │   ├── pengajian_card.dart
│   │   └── pengajian_status.dart
│   └── 📁 presensi/
│       ├── qr_scanner_widget.dart
│       ├── qr_display_widget.dart
│       ├── user_verify_dialog.dart
│       └── presensi_table.dart
│
├── 📁 utils/
│   ├── constants.dart
│   ├── helpers.dart
│   ├── menu_helper.dart
│   └── permissions.dart
│
├── 📁 routes/
│   └── app_routes.dart
│
└── main.dart
```

---

## 2. STRUKTUR HIERARKI (4 Level)

### 2.1 Visualisasi

```
📁 DAERAH (Level 0 - ROOT)
│
├── 📁 DESA A (Level 1)
│   │
│   ├── 📁 KELOMPOK 1 (Level 2)
│   │   ├── 👶 CABERAWIT (Level 3) ─── SD ke bawah
│   │   ├── 🧒 PRAREMAJA (Level 3) ─── SMP
│   │   ├── 👦 REMAJA (Level 3) ─── SMA - Pranikah
│   │   └── 👨 KELOMPOK (Level 3) ─── Nikah - Lansia
│   │
│   └── 📁 KELOMPOK 2, 3...
│
└── 📁 DESA B, C...
```

### 2.2 Kategori Usia

| Nama | Kriteria | Kode |
|------|----------|------|
| Caberawit | SD ke bawah | `caberawit` |
| Praremaja | SMP | `praremaja` |
| Remaja | SMA - Pranikah | `remaja` |
| Kelompok | Nikah - Lansia | `kelompok` |

---

## 3. ATURAN PENGAJIAN

### 3.1 Jenis per Level

| Level | Jenis | Peserta |
|-------|-------|---------|
| Daerah | Pengajian Daerah | Semua Desa |
| Desa | Pengajian Desa | Semua Kelompok |
| Kelompok | Pengajian Kelompok | Semua Kategori |
| Kategori | Pengajian Kategori | Hanya kategori tersebut |

### 3.2 Aturan Akses

```
✅ Bisa ikut pengajian di level sendiri
✅ Bisa ikut pengajian di parent (ke atas)
❌ Tidak bisa ikut di sibling (beda jalur)
❌ Tidak bisa ikut di level lebih rendah
```

---

## 4. ATURAN ADMIN

```
✅ Admin bisa KONTROL ke BAWAH (children)
✅ Admin bisa ASSIGN ADMIN ke BAWAH
❌ Admin TIDAK BISA kontrol ke ATAS
```

| Role | Bisa Kontrol |
|------|--------------|
| Admin Daerah | Semua Desa, Kelompok, Kategori |
| Admin Desa | Kelompok & Kategori di desanya |
| Admin Kelompok | Kategori di kelompoknya |
| Admin Kategori | Hanya levelnya |

---

## 5. SISTEM PRESENSI QR HYBRID

### 5.1 Alur

```
FASE 1: Admin buat pengajian → QR di-generate per user

FASE 2: Pengajian berlangsung
├── HADIR via QR: User tunjukkan QR → Admin scan → Verifikasi
├── HADIR via Manual: Admin cari nama → Approve
└── IZIN: User upload foto + alasan → Admin approve/reject

FASE 3: Admin akhiri pengajian → User tanpa status = TIDAK HADIR
```

### 5.2 Status Presensi

| Status | Kondisi |
|--------|---------|
| `hadir` | Admin setujui (QR/manual) |
| `izin` | User izin + Admin setujui |
| `tidak_hadir` | Tidak ada aksi sampai selesai |

---

## 6. DATABASE SCHEMA

### 6.1 Table users (Profile)

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id), -- Link ke Supabase Auth
  username TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  
  -- Data Spesifik Generus
  status_warga TEXT CHECK (status_warga IN ('Warga Asli', 'Perantau')),
  asal TEXT, -- Diisi jika perantau
  keperluan TEXT, -- MT, Kuliah, Bekerja
  detail_keperluan TEXT, -- Nama Kampus / Tempat Kerja
  
  foto_profil TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 6.2 Table organizations

```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL, -- Format: parent-name-random (dijamin unik)
  type TEXT CHECK (type IN ('daerah', 'desa', 'kelompok', 'kategori_usia')),
  parent_id UUID REFERENCES organizations(id),
  level INTEGER DEFAULT 0,
  path TEXT[] DEFAULT '{}',
  age_category TEXT,
  is_active BOOLEAN DEFAULT true
);
```

### 6.3 Table user_organizations

```sql
CREATE TABLE user_organizations (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  org_id UUID REFERENCES organizations(id),
  role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  UNIQUE(user_id, org_id)
);
```

### 6.4 Table pengajian

```sql
CREATE TABLE pengajian (
  id UUID PRIMARY KEY,
  org_id UUID REFERENCES organizations(id),
  title TEXT NOT NULL,
  description TEXT, -- Tambahan
  location TEXT,    -- Tambahan
  target_audience TEXT,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_by UUID REFERENCES users(id)
);
```

### 6.5 Table pengajian_qr

```sql
CREATE TABLE pengajian_qr (
  id UUID PRIMARY KEY,
  pengajian_id UUID REFERENCES pengajian(id),
  user_id UUID REFERENCES users(id),
  qr_code TEXT UNIQUE NOT NULL,
  is_used BOOLEAN DEFAULT false,
  UNIQUE(pengajian_id, user_id)
);
```

### 6.6 Table presensi

```sql
CREATE TABLE presensi (
  id UUID PRIMARY KEY,
  pengajian_id UUID REFERENCES pengajian(id),
  user_id UUID REFERENCES users(id),
  status TEXT CHECK (status IN ('hadir', 'izin', 'tidak_hadir')),
  method TEXT CHECK (method IN ('qr', 'manual', 'izin', 'auto')),
  approved_by UUID,
  foto_izin TEXT,
  keterangan TEXT,
  UNIQUE(pengajian_id, user_id)
);
```

---

## 7. API ENDPOINTS (Supabase RPC/REST)

### Organizations
- `GET /organizations` - List org
- `POST /organizations` - Buat org
- `GET /organizations/{id}/children` - List children

### Pengajian
- `GET /pengajian` - List pengajian
- `POST /pengajian` - Buat pengajian + generate QR
- `PUT /pengajian/{id}/end` - Akhiri pengajian

### Presensi
- `GET /presensi/my-qr` - Get QR user
- `POST /presensi/scan` - Scan QR
- `POST /presensi/manual` - Approve manual
- `POST /presensi/izin` - Submit izin
- `PUT /presensi/izin/{id}` - Approve/reject izin

---

## 8. FITUR APLIKASI

### 8.1 Fitur Admin

| Fitur | Halaman |
|-------|---------|
| Kelola Organisasi | `organisasi_list_page.dart` |
| Buat Pengajian | `pengajian_form_page.dart` |
| Scan QR | `scan_qr_page.dart` |
| Approve Manual | `manual_approve_page.dart` |
| Kelola Izin | `kelola_izin_page.dart` |
| Rekap Presensi | `rekap_page.dart` |

### 8.2 Fitur User

| Fitur | Halaman |
|-------|---------|
| Dashboard | `dashboard_page.dart` |
| Lihat QR | `qr_page.dart` |
| Ajukan Izin | `izin_page.dart` |
| Riwayat | `riwayat_page.dart` |
| Profil | `profil_page.dart` |

---

## 9. MENU DINAMIS

```dart
// utils/menu_helper.dart
List<MenuItem> getMenuForUser(List<UserOrg> userOrgs) {
  final isAdmin = userOrgs.any((uo) => uo.role == 'admin');
  final lowestLevel = userOrgs.map((uo) => uo.org.level).reduce(min);
  
  if (!isAdmin) return getMemberMenu();
  
  switch (lowestLevel) {
    case 0: return getAdminDaerahMenu();
    case 1: return getAdminDesaMenu();
    case 2: return getAdminKelompokMenu();
    case 3: return getAdminKategoriMenu();
    default: return getMemberMenu();
  }
}
```

---

## 10. ALUR IMPLEMENTASI

### Fase 1: Database (Supabase)
- Jalankan semua SQL di folder `codeSQL/`

### Fase 2: Models
- Buat semua model di `lib/models/`

### Fase 3: Services
- Buat Supabase service untuk setiap fitur

### Fase 4: Controllers
- Buat controller dengan GetX/Provider

### Fase 5: Pages
- Implementasi halaman admin & user

### Fase 6: Widgets
- QR Scanner, QR Display, dll

### Dependencies

```yaml
dependencies:
  supabase_flutter: ^2.0.0
  get: ^4.6.5
  qr_flutter: ^4.1.0
  mobile_scanner: ^3.5.0
  image_picker: ^1.0.0
  cached_network_image: ^3.3.0
```

---

**Dokumen ini adalah acuan lengkap untuk implementasi Flutter.**

*Terakhir diupdate: 23 Januari 2026*
