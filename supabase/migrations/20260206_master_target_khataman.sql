-- Migration: Create master_target_khataman table
-- Tabel untuk menyimpan daftar master target bacaan (Al-Quran, Hadis, dll)

CREATE TABLE IF NOT EXISTS master_target_khataman (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL,
  nama TEXT NOT NULL,
  jumlah_halaman INTEGER NOT NULL DEFAULT 0,
  keterangan TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID
);

-- Enable RLS
ALTER TABLE master_target_khataman ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can read master_target_khataman" ON master_target_khataman;
DROP POLICY IF EXISTS "Users can insert master_target_khataman" ON master_target_khataman;
DROP POLICY IF EXISTS "Users can update master_target_khataman" ON master_target_khataman;
DROP POLICY IF EXISTS "Users can delete master_target_khataman" ON master_target_khataman;
DROP POLICY IF EXISTS "allow_select_master_target" ON master_target_khataman;
DROP POLICY IF EXISTS "allow_insert_master_target" ON master_target_khataman;
DROP POLICY IF EXISTS "allow_update_master_target" ON master_target_khataman;
DROP POLICY IF EXISTS "allow_delete_master_target" ON master_target_khataman;

-- Simple policies that allow all authenticated users
CREATE POLICY "master_target_select" ON master_target_khataman
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "master_target_insert" ON master_target_khataman
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "master_target_update" ON master_target_khataman
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "master_target_delete" ON master_target_khataman
  FOR DELETE USING (auth.role() = 'authenticated');

-- Add comments for documentation
COMMENT ON TABLE master_target_khataman IS 'Master data for khataman targets (Al-Quran, Hadis, etc)';
COMMENT ON COLUMN master_target_khataman.nama IS 'Name of the target (e.g., Al-Quran, Hadis Bukhari)';
COMMENT ON COLUMN master_target_khataman.jumlah_halaman IS 'Total pages to complete';
COMMENT ON COLUMN master_target_khataman.keterangan IS 'Additional description/notes';
