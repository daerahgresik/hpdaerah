-- ============================================
-- STEP 2: TABLE ORGANIZATIONS (Hierarki)
-- ============================================

CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('daerah', 'desa', 'kelompok', 'kategori_usia')),
  parent_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  level INTEGER DEFAULT 0 CHECK (level >= 0 AND level <= 3),
  path TEXT[] DEFAULT '{}',
  age_category TEXT CHECK (age_category IN ('caberawit', 'praremaja', 'muda_mudi', 'kelompok', NULL)),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);

CREATE INDEX idx_org_parent ON organizations(parent_id);
CREATE INDEX idx_org_type ON organizations(type);
CREATE INDEX idx_org_level ON organizations(level);
CREATE INDEX idx_org_slug ON organizations(slug);
CREATE INDEX idx_org_path ON organizations USING GIN(path);

ALTER TABLE users 
ADD CONSTRAINT fk_users_current_org 
FOREIGN KEY (current_org_id) REFERENCES organizations(id);
