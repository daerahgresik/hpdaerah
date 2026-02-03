-- =====================================================
-- Migration: Prevent Duplicate Room Codes & Overlapping Rooms
-- Created: 2026-02-04
-- Description: 
--   1. Unique constraint untuk room_code aktif
--   2. Index untuk mempercepat query pengecekan overlap
-- =====================================================

-- 1. UNIQUE PARTIAL INDEX untuk room_code yang masih aktif
-- Memastikan tidak ada 2 room aktif dengan kode yang sama
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_room_code 
ON pengajian (room_code) 
WHERE is_template = false AND ended_at IS NULL;

-- 2. INDEX untuk mempercepat query overlap check
-- Digunakan oleh checkOverlappingRoom() di Flutter
CREATE INDEX IF NOT EXISTS idx_pengajian_overlap_check 
ON pengajian (org_id, org_daerah_id, org_desa_id, org_kelompok_id, started_at, ended_at) 
WHERE is_template = false;

-- 3. INDEX untuk query room by code (untuk join by code feature)
CREATE INDEX IF NOT EXISTS idx_pengajian_room_code 
ON pengajian (room_code) 
WHERE is_template = false AND ended_at IS NULL;

-- 4. Optional: Constraint untuk mencegah room dengan durasi negatif
ALTER TABLE pengajian 
ADD CONSTRAINT chk_pengajian_valid_duration 
CHECK (ended_at IS NULL OR ended_at > started_at);

-- =====================================================
-- CARA MENJALANKAN:
-- 1. Buka Supabase Dashboard → SQL Editor
-- 2. Copy-paste seluruh isi file ini
-- 3. Klik "Run"
-- =====================================================
