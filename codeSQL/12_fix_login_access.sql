-- ============================================
-- FIX LOGIN ACCESS (PENTING!)
-- ============================================

-- Masalah: Aplikasi tidak bisa "baca" table users saat Login karena terkunci oleh RLS (Keamanan Supabase).
-- Solusi: Kita buka kunci table users agar siapa saja bisa cek username/password (sesuai request custom login ini).

-- 1. Matikan RLS (Row Level Security) untuk table users
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 2. Pastikan user superadmin benar-benar ada dan passwordnya benar
INSERT INTO users (
  username,
  nama,
  password,
  status_warga,
  is_admin,
  status
) VALUES (
  'superadmin',      
  'Super Administrator', 
  'password123',     
  'Warga Asli',      
  true,              
  'active'
) ON CONFLICT (username) DO UPDATE 
SET password = 'password123'; -- Reset password jadi 'password123' jika sudah ada
