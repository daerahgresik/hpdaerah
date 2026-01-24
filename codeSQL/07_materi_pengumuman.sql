-- ============================================
-- STEP 7: TABLE MATERI & PENGUMUMAN
-- ============================================

CREATE TABLE materi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  tanggal TEXT NOT NULL,
  guru TEXT[],
  isi TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_materi_org ON materi(org_id);
CREATE INDEX idx_materi_date ON materi(created_at);

CREATE TABLE pengumuman (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  tanggal TEXT NOT NULL,
  isi TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pengumuman_org ON pengumuman(org_id);
CREATE INDEX idx_pengumuman_date ON pengumuman(created_at);
