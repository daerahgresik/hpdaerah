-- Migration: Add target_kelas_ids and target_mode to pengajian table
-- This enables class-based targeting for pengajian rooms

ALTER TABLE pengajian
ADD COLUMN IF NOT EXISTS target_kelas_ids TEXT[] DEFAULT NULL;

ALTER TABLE pengajian
ADD COLUMN IF NOT EXISTS target_mode TEXT DEFAULT 'all';

-- Add comment for documentation
COMMENT ON COLUMN pengajian.target_kelas_ids IS 'Array of kelas IDs that are targeted for this pengajian';
COMMENT ON COLUMN pengajian.target_mode IS 'Target mode: all, kelas, or kriteria';
