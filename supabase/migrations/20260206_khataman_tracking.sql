-- Migration: Khataman Progress Tracking System
-- Tabel untuk tracking progress khataman dengan real-time data

-- 1. Target Assignment: Assign target ke kelas atau user
CREATE TABLE IF NOT EXISTS khataman_assignment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL,
  master_target_id UUID NOT NULL,
  -- Target bisa untuk kelas ATAU user, salah satu harus diisi
  kelas_id UUID,
  user_id UUID,
  target_type TEXT NOT NULL CHECK (target_type IN ('kelas', 'user')),
  deadline DATE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID,
  CONSTRAINT chk_target CHECK (
    (target_type = 'kelas' AND kelas_id IS NOT NULL AND user_id IS NULL) OR
    (target_type = 'user' AND user_id IS NOT NULL AND kelas_id IS NULL)
  )
);

-- 2. Progress Tracking: Track halaman yang sudah dibaca per user
CREATE TABLE IF NOT EXISTS khataman_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id UUID NOT NULL,
  user_id UUID NOT NULL,
  halaman_selesai INTEGER NOT NULL DEFAULT 0,
  catatan TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(assignment_id, user_id)
);

-- Enable RLS
ALTER TABLE khataman_assignment ENABLE ROW LEVEL SECURITY;
ALTER TABLE khataman_progress ENABLE ROW LEVEL SECURITY;

-- Policies for khataman_assignment
CREATE POLICY "Read khataman_assignment" ON khataman_assignment FOR SELECT TO authenticated USING (true);
CREATE POLICY "Insert khataman_assignment" ON khataman_assignment FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Update khataman_assignment" ON khataman_assignment FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Delete khataman_assignment" ON khataman_assignment FOR DELETE TO authenticated USING (true);

-- Policies for khataman_progress  
CREATE POLICY "Read khataman_progress" ON khataman_progress FOR SELECT TO authenticated USING (true);
CREATE POLICY "Insert khataman_progress" ON khataman_progress FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Update khataman_progress" ON khataman_progress FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Delete khataman_progress" ON khataman_progress FOR DELETE TO authenticated USING (true);

-- Enable Realtime for live tracking
ALTER PUBLICATION supabase_realtime ADD TABLE khataman_assignment;
ALTER PUBLICATION supabase_realtime ADD TABLE khataman_progress;

-- Comments
COMMENT ON TABLE khataman_assignment IS 'Target khataman yang di-assign ke kelas atau user';
COMMENT ON TABLE khataman_progress IS 'Progress baca per user (halaman yang sudah selesai)';
