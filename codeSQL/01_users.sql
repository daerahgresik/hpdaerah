-- ============================================
-- STEP 1: TABLE USERS (Base Table)
-- ============================================
-- Jalankan ini PERTAMA di Supabase SQL Editor
-- Klik "Run" atau tekan Ctrl+Enter

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  nama TEXT NOT NULL,
  tanggal_lahir DATE,
  jenis_kelamin TEXT,
  status TEXT,
  password TEXT NOT NULL,
  asal TEXT,
  status TEXT DEFAULT 'active',
  jabatan TEXT,
  keterangan TEXT,
  foto_profil TEXT,
  foto_sampul TEXT,
  is_admin BOOLEAN DEFAULT false,
  current_org_id UUID,  -- akan di-link ke organizations nanti
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index untuk pencarian
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_is_admin ON users(is_admin);

-- Verifikasi: Setelah run, cek di Table Editor apakah table 'users' sudah muncul
