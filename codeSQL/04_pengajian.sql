-- ============================================
-- STEP 4: TABLE PENGAJIAN (Session)
-- ============================================

CREATE TABLE pengajian (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  target_audience TEXT CHECK (target_audience IN ('muda_mudi', NULL)),
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pengajian_org ON pengajian(org_id);
CREATE INDEX idx_pengajian_active ON pengajian(ended_at) WHERE ended_at IS NULL;
CREATE INDEX idx_pengajian_date ON pengajian(started_at);
CREATE INDEX idx_pengajian_created_by ON pengajian(created_by);
