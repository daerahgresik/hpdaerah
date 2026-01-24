-- ============================================
-- STEP 6: TABLE PRESENSI (Kehadiran)
-- ============================================

CREATE TABLE presensi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pengajian_id UUID NOT NULL REFERENCES pengajian(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('hadir', 'izin', 'tidak_hadir')),
  method TEXT CHECK (method IN ('qr', 'manual', 'izin', 'auto')),
  approved_by UUID REFERENCES users(id),
  foto_izin TEXT,
  keterangan TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(pengajian_id, user_id)
);

CREATE INDEX idx_presensi_pengajian ON presensi(pengajian_id);
CREATE INDEX idx_presensi_user ON presensi(user_id);
CREATE INDEX idx_presensi_status ON presensi(status);
