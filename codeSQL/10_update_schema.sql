-- ================================================================
-- MIGRATION: UPDATE SCHEMA & CONSTRAINT
-- Jalankan ini SEBELUM setup_organizations.sql
-- ================================================================

-- 1. Update Table USERS: Tambah kolom baru untuk Register
ALTER TABLE users ADD COLUMN IF NOT EXISTS status_warga TEXT CHECK (status_warga IN ('Warga Asli', 'Perantau'));
ALTER TABLE users ADD COLUMN IF NOT EXISTS keperluan TEXT; -- MT, Kuliah, Bekerja
ALTER TABLE users ADD COLUMN IF NOT EXISTS detail_keperluan TEXT; -- Nama Kampus / Tempat Kerja
-- 'asal' sudah ada di schema lama, tapi jika belum:
ALTER TABLE users ADD COLUMN IF NOT EXISTS asal TEXT;

-- 2. Update Table ORGANIZATIONS: Ubah constraint age_category (Muda-Mudi -> Remaja)
-- Kita harus drop constraint lama dulu
ALTER TABLE organizations DROP CONSTRAINT IF EXISTS organizations_age_category_check;

-- Add constraint baru dengan 'remaja'
ALTER TABLE organizations ADD CONSTRAINT organizations_age_category_check 
CHECK (age_category IN ('caberawit', 'praremaja', 'remaja', 'kelompok', 'muda_mudi')); 
-- Note: Saya biarkan 'muda_mudi' jaga-jaga jika ada data lama, tapi kita pakai 'remaja' ke depan.

-- 3. (Optional) Jika Table Users belum punya kolom 'role' atau link user_organizations
-- (Sudah ada di table user_organizations terpisah, jadi aman)
