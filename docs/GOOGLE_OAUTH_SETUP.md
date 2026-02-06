# Dokumentasi Setup Google OAuth untuk HP Daerah

Dokumen ini berisi semua kredensial dan langkah-langkah setup Google OAuth untuk aplikasi HP Daerah.

---

## 📋 Informasi Proyek

| Keterangan | Nilai |
|------------|-------|
| **Nama Proyek Google Cloud** | hpdaerah |
| **Project ID Supabase** | hjzvfvqiqpibnjvddbfr |
| **Supabase URL** | https://hjzvfvqiqpibnjvddbfr.supabase.co |
| **Package Name Android** | com.bayuence.hpdaerah |
| **GitHub Pages URL** | https://daerahgresik.github.io/hpdaerah/ |

---

## 🔐 Kredensial OAuth

### Web Client
| Keterangan | Nilai |
|------------|-------|
| **Nama** | hpdaerah-web |
| **Client ID** | `1030484373460-oi997gf0mkt0c5o7kkddrmi5dv4o5r6p.apps.googleusercontent.com` |
| **Client Secret** | `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` |

**Authorized JavaScript Origins:**
- `http://localhost`
- `http://localhost:5000`
- `https://daerahgresik.github.io`

**Authorized Redirect URIs:**
- `https://hjzvfvqiqpibnjvddbfr.supabase.co/auth/v1/callback`

---

### Android Client
| Keterangan | Nilai |
|------------|-------|
| **Nama** | hpdaerah-android |
| **Client ID** | `1030484373460-5pnr7edd95ira7rtvf82tku6cr2fcka7.apps.googleusercontent.com` |
| **Package Name** | `com.bayuence.hpdaerah` |
| **SHA-1 Fingerprint (Debug)** | `1B:AE:B5:14:DD:B9:AD:ED:83:AD:86:25:54:09:81:F8:65:77:D4:10` |

---

### iOS Client
> ⚠️ Belum dibuat. Membutuhkan Apple Developer Account.

---

## 🔗 Link Penting

- **Google Cloud Console:** https://console.cloud.google.com/
- **Supabase Dashboard:** https://supabase.com/dashboard/project/hjzvfvqiqpibnjvddbfr
- **Google Auth Platform:** https://console.cloud.google.com/auth/clients?project=hpdaerah

---

## 📝 Cara Mendapatkan SHA-1 Fingerprint

Jalankan command ini di terminal (PowerShell):

```powershell
keytool -keystore "$env:USERPROFILE\.android\debug.keystore" -list -v -alias androiddebugkey -storepass android -keypass android
```

---

## ✅ Status Setup

- [x] Web OAuth Client - SELESAI
- [x] Android OAuth Client - SELESAI  
- [x] Supabase Google Provider - SELESAI
- [ ] iOS OAuth Client - BELUM
- [ ] Implementasi Flutter - BELUM

---

## 📅 Tanggal Setup

**Tanggal:** 7 Februari 2026

---

## 🚀 Langkah Selanjutnya

1. Implementasi Google Sign-In di Flutter
2. Modifikasi halaman Register untuk menambahkan tombol "Hubungkan dengan Google"
3. Modifikasi halaman Login untuk mendukung login dengan Google
4. (Opsional) Setup iOS OAuth Client jika diperlukan

---

> **PENTING:** Jangan share Client Secret ke publik! File ini hanya untuk referensi internal.
