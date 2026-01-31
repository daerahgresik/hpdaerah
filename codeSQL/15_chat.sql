-- ============================================
-- 15. CHAT FEATURE (Complete Setup)
-- ============================================
-- File ini menggabungkan pembuatan table, indexing, 
-- realtime setup, dan security policy yang sudah diperbaiki.

-- 1. Table Chat Messages
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  is_system_message BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Indexing untuk Performa
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_created ON chat_messages(room_id, created_at DESC);

-- 3. Enable Realtime
-- Agar pesan muncul otomatis tanpa refresh
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  END IF;
END $$;

-- 4. Security Policies (RLS)
-- Menggunakan PUBLIC access karena aplikasi menggunakan Custom Login
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Bersihkan policy lama jika ada
DROP POLICY IF EXISTS "Users can send messages to their organizations" ON chat_messages;
DROP POLICY IF EXISTS "Users can read messages in their organizations" ON chat_messages;
DROP POLICY IF EXISTS "Public insert chat" ON chat_messages;
DROP POLICY IF EXISTS "Public read chat" ON chat_messages;
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Public access users" ON users;

-- Policy untuk Chat Messages
CREATE POLICY "Public insert chat" ON chat_messages FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Public read chat" ON chat_messages FOR SELECT TO public USING (true);

-- Policy untuk Users (Agar login dan chat bisa baca data user)
CREATE POLICY "Public access users" ON users FOR SELECT TO public USING (true);
