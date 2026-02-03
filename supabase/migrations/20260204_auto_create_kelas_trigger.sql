-- ============================================
-- TRIGGER: AUTO CREATE KELAS DEFAULT
-- Ketika kelompok baru dibuat, otomatis buat 4 kelas default
-- ============================================

-- Function untuk create kelas default
CREATE OR REPLACE FUNCTION create_default_kelas()
RETURNS TRIGGER AS $$
BEGIN
  -- Hanya untuk organization level 2 (Kelompok)
  IF NEW.level = 2 THEN
    INSERT INTO public.kelas (org_kelompok_id, nama, deskripsi) VALUES
      (NEW.id, 'Umum', 'Kelas untuk usia dewasa'),
      (NEW.id, 'Muda-Mudi', 'Kelas untuk pemuda dan pemudi'),
      (NEW.id, 'Praremaja', 'Kelas untuk usia praremaja'),
      (NEW.id, 'Caberawit', 'Kelas untuk anak-anak');
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger jika sudah ada
DROP TRIGGER IF EXISTS trg_auto_create_kelas ON public.organizations;

-- Create trigger
CREATE TRIGGER trg_auto_create_kelas
  AFTER INSERT ON public.organizations
  FOR EACH ROW
  EXECUTE FUNCTION create_default_kelas();

-- ============================================
-- SELESAI!
-- Sekarang setiap kelompok baru akan otomatis punya 4 kelas:
-- 1. Umum
-- 2. Muda-Mudi
-- 3. Praremaja
-- 4. Caberawit
-- ============================================
