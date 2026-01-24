-- ============================================
-- STEP 3: TABLE USER_ORGANIZATIONS (Relasi)
-- ============================================

CREATE TABLE user_organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, org_id)
);

CREATE INDEX idx_user_org_user ON user_organizations(user_id);
CREATE INDEX idx_user_org_org ON user_organizations(org_id);
CREATE INDEX idx_user_org_role ON user_organizations(role);
