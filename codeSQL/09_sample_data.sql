-- ============================================
-- STEP 9: SAMPLE DATA
-- ============================================

-- Insert Super Admin
INSERT INTO users (username, nama, password, is_admin) VALUES
('superadmin', 'Super Admin', 'admin123', true);

-- Insert Daerah Gresik (Level 0)
INSERT INTO organizations (name, slug, type) VALUES
('Daerah Gresik', 'daerah-gresik', 'daerah');

-- ============================================
-- VERIFIKASI SEMUA TABLE
-- ============================================
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
