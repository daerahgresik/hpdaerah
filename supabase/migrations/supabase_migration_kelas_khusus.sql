-- ============================================================================
-- MIGRATION: Kelas Khusus & Sub-Kelas
-- Jalankan script ini di Supabase Dashboard → SQL Editor → New Query → Run
-- ============================================================================

-- 1. Tambah kolom org_id: ID organisasi pemilik (bisa Daerah/Desa/Kelompok)
ALTER TABLE kelas ADD COLUMN IF NOT EXISTS org_id UUID REFERENCES organizations(id);

-- 2. Tambah kolom org_level: tingkat organisasi pemilik
--    1 = Daerah, 2 = Desa, 3 = Kelompok
ALTER TABLE kelas ADD COLUMN IF NOT EXISTS org_level INTEGER DEFAULT 3;

-- 3. Tambah kolom parent_kelas_id: untuk relasi parent-child (sub-kelas)
ALTER TABLE kelas ADD COLUMN IF NOT EXISTS parent_kelas_id UUID REFERENCES kelas(id) ON DELETE CASCADE;

-- 4. Buat org_kelompok_id nullable (kelas daerah/desa tidak punya kelompok)
ALTER TABLE kelas ALTER COLUMN org_kelompok_id DROP NOT NULL;

-- 5. Isi org_id dari data yang sudah ada (kelas lama = level kelompok)
UPDATE kelas SET org_id = org_kelompok_id, org_level = 3 WHERE org_id IS NULL;

-- 6. Index untuk performa query
CREATE INDEX IF NOT EXISTS idx_kelas_org_id ON kelas(org_id);
CREATE INDEX IF NOT EXISTS idx_kelas_org_level ON kelas(org_level);
CREATE INDEX IF NOT EXISTS idx_kelas_parent_kelas_id ON kelas(parent_kelas_id);

-- ============================================================================
-- SELESAI! Setelah menjalankan ini, hot reload aplikasi Flutter.
-- ============================================================================
