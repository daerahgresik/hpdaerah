-- ============================================
-- ADD ROOM CODE JOIN SUPPORT
-- Kolom tambahan untuk mendukung fitur join via room code
-- ============================================

-- Tambah kolom join_method untuk menandai cara user join pengajian
-- Nilai: 'target' (default, dijadikan target), 'room_code' (join via kode), 'admin_invite' (dibawa admin)
ALTER TABLE public.pengajian_qr
  ADD COLUMN IF NOT EXISTS join_method VARCHAR(20) DEFAULT 'target';

-- Tambah kolom untuk mencatat admin yang mengundang user (jika join via admin_invite)
ALTER TABLE public.pengajian_qr
  ADD COLUMN IF NOT EXISTS invited_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Index untuk query berdasarkan join_method
CREATE INDEX IF NOT EXISTS idx_pengajian_qr_join_method ON public.pengajian_qr(join_method);

-- ============================================
-- KOMENTAR DOKUMENTASI
-- ============================================
COMMENT ON COLUMN public.pengajian_qr.join_method IS 'Cara user bergabung: target (default), room_code (via kode), admin_invite (dibawa admin)';
COMMENT ON COLUMN public.pengajian_qr.invited_by_admin_id IS 'ID admin yang mengundang user (untuk join_method = admin_invite)';

