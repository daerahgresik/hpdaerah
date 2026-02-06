-- Menambahkan kolom email dan google_id ke tabel users
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS email TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;

-- Index untuk pencarian cepat saat login
CREATE INDEX IF NOT EXISTS users_email_idx ON public.users (email);
CREATE INDEX IF NOT EXISTS users_google_id_idx ON public.users (google_id);
