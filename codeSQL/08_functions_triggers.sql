-- ============================================
-- STEP 8: FUNCTIONS & TRIGGERS
-- ============================================

CREATE OR REPLACE FUNCTION update_org_path()
RETURNS TRIGGER AS $$
DECLARE
  parent_path TEXT[];
BEGIN
  IF NEW.parent_id IS NULL THEN
    NEW.path := ARRAY[NEW.id::TEXT];
    NEW.level := 0;
  ELSE
    SELECT path INTO parent_path FROM organizations WHERE id = NEW.parent_id;
    NEW.path := parent_path || NEW.id::TEXT;
    NEW.level := array_length(parent_path, 1);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_org_path ON organizations;
CREATE TRIGGER trg_org_path
  BEFORE INSERT OR UPDATE ON organizations
  FOR EACH ROW
  EXECUTE FUNCTION update_org_path();

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated ON users;
CREATE TRIGGER trg_users_updated
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_org_updated ON organizations;
CREATE TRIGGER trg_org_updated
  BEFORE UPDATE ON organizations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_presensi_updated ON presensi;
CREATE TRIGGER trg_presensi_updated
  BEFORE UPDATE ON presensi
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
