-- ============================================
-- INSERT KELAS DEFAULT UNTUK SEMUA KELOMPOK
-- Kelas: Umum (dewasa), Muda-Mudi, Praremaja, Caberawit
-- ============================================

-- Insert 4 kelas default untuk setiap kelompok (level 2)
INSERT INTO public.kelas (org_kelompok_id, nama, deskripsi)
SELECT 
  o.id,
  k.nama,
  k.deskripsi
FROM public.organizations o
CROSS JOIN (
  VALUES 
    ('Umum', 'Kelas untuk usia dewasa'),
    ('Muda-Mudi', 'Kelas untuk pemuda dan pemudi'),
    ('Praremaja', 'Kelas untuk usia praremaja'),
    ('Caberawit', 'Kelas untuk anak-anak')
) AS k(nama, deskripsi)
WHERE o.level = 2  -- Level 2 = Kelompok
ON CONFLICT (org_kelompok_id, nama) DO NOTHING;

-- Lihat hasil
SELECT 
  k.id,
  k.nama,
  k.deskripsi,
  o.name as kelompok_name
FROM public.kelas k
JOIN public.organizations o ON k.org_kelompok_id = o.id
ORDER BY o.name, k.nama;
