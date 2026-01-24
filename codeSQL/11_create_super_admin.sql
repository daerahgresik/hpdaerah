-- ============================================
-- SUPER ADMIN CREATION
-- ============================================

-- Masukkan user 'superadmin' ke table users
INSERT INTO users (
  username,
  nama,
  password,
  status_warga,
  is_admin,
  status
) VALUES (
  'superadmin',      -- Username
  'Super Administrator', -- Nama
  'password123',     -- Password (plain text)
  'Warga Asli',      -- Default Status
  true,              -- Set TRUE agar jadi Super Admin
  'active'
) ON CONFLICT (username) DO NOTHING;

-- Notifikasi
-- User superadmin telah dibuat.
-- Username: superadmin
-- Password: password123
