-- Menambahkan kolom hierarki eksplisit ke tabel users untuk memudahkan query & reporting
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS org_daerah_id UUID REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS org_desa_id UUID REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS org_kelompok_id UUID REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS org_kategori_id UUID REFERENCES organizations(id);

-- Indexing untuk performa filtering query
CREATE INDEX IF NOT EXISTS idx_users_org_daerah ON public.users(org_daerah_id);
CREATE INDEX IF NOT EXISTS idx_users_org_desa ON public.users(org_desa_id);
CREATE INDEX IF NOT EXISTS idx_users_org_kelompok ON public.users(org_kelompok_id);
CREATE INDEX IF NOT EXISTS idx_users_org_kategori ON public.users(org_kategori_id);
