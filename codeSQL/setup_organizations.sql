-- ================================================================
-- SEED DATA ORGANIZATIONS HIERARCHY
-- Jalankan SETELAH 10_update_schema.sql
-- ================================================================

-- 1. Insert DAERAH (Level 0)
INSERT INTO organizations (id, name, slug, type, level, parent_id, path)
VALUES 
('d0000000-0000-0000-0000-000000000001', 'Daerah Pusat', 'daerah-pusat', 'daerah', 0, NULL, ARRAY['d0000000-0000-0000-0000-000000000001'])
ON CONFLICT (id) DO NOTHING;

-- 2. Insert DESA (Level 1)
INSERT INTO organizations (id, name, slug, type, level, parent_id, path)
VALUES 
('d1000000-0000-0000-0000-000000000001', 'Desa Timur 1', 'desa-timur-1', 'desa', 1, 'd0000000-0000-0000-0000-000000000001', ARRAY['d0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001']),
('d1000000-0000-0000-0000-000000000002', 'Desa Barat 1', 'desa-barat-1', 'desa', 1, 'd0000000-0000-0000-0000-000000000001', ARRAY['d0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000002'])
ON CONFLICT (id) DO NOTHING;

-- 3. Insert KELOMPOK (Level 2)
INSERT INTO organizations (id, name, slug, type, level, parent_id, path)
VALUES 
('d2000000-0000-0000-0000-000000000001', 'Kelompok Timur 1A', 'kelompok-timur-1a', 'kelompok', 2, 'd1000000-0000-0000-0000-000000000001', ARRAY['d0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000001']),
('d2000000-0000-0000-0000-000000000002', 'Kelompok Timur 1B', 'kelompok-timur-1b', 'kelompok', 2, 'd1000000-0000-0000-0000-000000000001', ARRAY['d0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000002'])
ON CONFLICT (id) DO NOTHING;

-- 4. Insert KELAS (Level 3)
-- Menggunakan ON CONFLICT DO NOTHING untuk mencegah error duplikasi slug jika dijalankan ulang
INSERT INTO organizations (name, slug, type, level, parent_id, age_category, path)
VALUES 
('Caberawit Timur 1A', 'caberawit-timur-1a', 'kategori_usia', 3, 'd2000000-0000-0000-0000-000000000001', 'caberawit', ARRAY['d0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000001', gen_random_uuid()::text]),

('Praremaja Timur 1A', 'praremaja-timur-1a', 'kategori_usia', 3, 'd2000000-0000-0000-0000-000000000001', 'praremaja', ARRAY['d0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000001', gen_random_uuid()::text]),

('Remaja Timur 1A',    'remaja-timur-1a',    'kategori_usia', 3, 'd2000000-0000-0000-0000-000000000001', 'remaja',    ARRAY['d0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000001', gen_random_uuid()::text]),

('Kelompok Timur 1A',  'kelompok-timur-1a-lvl3',  'kategori_usia', 3, 'd2000000-0000-0000-0000-000000000001', 'kelompok',  ARRAY['d0000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000001', gen_random_uuid()::text]);
