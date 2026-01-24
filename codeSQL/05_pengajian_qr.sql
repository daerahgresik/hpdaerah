-- ============================================
-- STEP 5: TABLE PENGAJIAN_QR (QR Code)
-- ============================================

CREATE TABLE pengajian_qr (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pengajian_id UUID NOT NULL REFERENCES pengajian(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  qr_code TEXT UNIQUE NOT NULL,
  is_used BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(pengajian_id, user_id)
);

CREATE INDEX idx_qr_pengajian ON pengajian_qr(pengajian_id);
CREATE INDEX idx_qr_user ON pengajian_qr(user_id);
CREATE INDEX idx_qr_code ON pengajian_qr(qr_code);
CREATE INDEX idx_qr_unused ON pengajian_qr(is_used) WHERE is_used = false;
