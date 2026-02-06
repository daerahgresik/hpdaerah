-- Add Foreign Key relationships for Khataman Features
-- Fixes error: Could not find a relationship between 'khataman_assignment' and 'master_target_khataman'

-- 1. Add relations to khataman_assignment
ALTER TABLE khataman_assignment
ADD CONSTRAINT fk_khataman_master_target
FOREIGN KEY (master_target_id)
REFERENCES master_target_khataman(id)
ON DELETE CASCADE;

ALTER TABLE khataman_assignment
ADD CONSTRAINT fk_khataman_kelas
FOREIGN KEY (kelas_id)
REFERENCES kelas(id)
ON DELETE SET NULL;

ALTER TABLE khataman_assignment
ADD CONSTRAINT fk_khataman_user
FOREIGN KEY (user_id)
REFERENCES users(id)
ON DELETE SET NULL;

-- 2. Add relations to khataman_progress
ALTER TABLE khataman_progress
ADD CONSTRAINT fk_progress_assignment
FOREIGN KEY (assignment_id)
REFERENCES khataman_assignment(id)
ON DELETE CASCADE;

ALTER TABLE khataman_progress
ADD CONSTRAINT fk_progress_user
FOREIGN KEY (user_id)
REFERENCES users(id)
ON DELETE CASCADE;

-- 3. Reload schema cache (optional but recommended)
NOTIFY pgrst, 'reload config';
