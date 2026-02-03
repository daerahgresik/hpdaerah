-- ============================================
-- TABEL KELAS - Kategori pengajian per Kelompok
-- ============================================

CREATE TABLE IF NOT EXISTS public.kelas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_kelompok_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  nama VARCHAR(100) NOT NULL,
  deskripsi TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique constraint: nama kelas unik per kelompok
  UNIQUE(org_kelompok_id, nama)
);

-- Index untuk query berdasarkan kelompok
CREATE INDEX IF NOT EXISTS idx_kelas_kelompok ON public.kelas(org_kelompok_id);

-- Trigger update timestamp
DROP TRIGGER IF EXISTS trg_kelas_updated ON public.kelas;
CREATE TRIGGER trg_kelas_updated 
  BEFORE UPDATE ON public.kelas 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at();

-- ============================================
-- BERSIHKAN DATA LAMA org_kategori_id
-- Karena referensi lama tidak valid
-- ============================================

UPDATE public.users SET org_kategori_id = NULL WHERE org_kategori_id IS NOT NULL;

-- ============================================
-- UPDATE FOREIGN KEY users.org_kategori_id
-- Sekarang mereferensikan tabel kelas
-- ============================================

-- Drop existing constraint jika ada
ALTER TABLE public.users 
  DROP CONSTRAINT IF EXISTS users_org_kategori_id_fkey;

ALTER TABLE public.users 
  DROP CONSTRAINT IF EXISTS users_kelas_fkey;

-- Add new foreign key ke tabel kelas
ALTER TABLE public.users
  ADD CONSTRAINT users_kelas_fkey 
  FOREIGN KEY (org_kategori_id) 
  REFERENCES kelas(id) 
  ON DELETE SET NULL;

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

ALTER TABLE public.kelas ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Admin can view kelas in their hierarchy" ON public.kelas;
DROP POLICY IF EXISTS "Admin can manage kelas" ON public.kelas;

-- Admin bisa lihat kelas di hierarki mereka
CREATE POLICY "Admin can view kelas in their hierarchy"
  ON public.kelas FOR SELECT
  USING (true);

-- Admin bisa insert/update/delete kelas
CREATE POLICY "Admin can manage kelas"
  ON public.kelas FOR ALL
  USING (true)
  WITH CHECK (true);
