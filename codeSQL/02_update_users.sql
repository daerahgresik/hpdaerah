-- MIGRASI TABEL USERS 
-- 1. Hapus constraint lama jika ada
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_status_warga_check;
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_status_check;

-- 2. Rename kolom 'asal' (Kota) menjadi 'asal_daerah'
ALTER TABLE public.users RENAME COLUMN asal TO asal_daerah;

-- 3. Rename kolom 'status' (Akun) menjadi 'asal' (Status Warga: Asli/Perantau)
-- Dan hapus default 'active'
ALTER TABLE public.users RENAME COLUMN status TO asal;
ALTER TABLE public.users ALTER COLUMN asal DROP DEFAULT;

-- 4. Tambah kolom baru
ALTER TABLE public.users ADD COLUMN status TEXT; -- Sekarang untuk Status Pernikahan
ALTER TABLE public.users ADD COLUMN jenis_kelamin TEXT;
ALTER TABLE public.users ADD COLUMN tanggal_lahir DATE;
ALTER TABLE public.users ADD COLUMN account_status TEXT DEFAULT 'active'; -- Pindahkan status akun ke kolom baru

-- 5. Pindahkan data dari status_warga ke asal (jika ada data)
UPDATE public.users SET asal = status_warga WHERE status_warga IS NOT NULL;

-- 6. Hapus kolom status_warga yang sudah tidak terpakai
ALTER TABLE public.users DROP COLUMN IF EXISTS status_warga;

-- 7. Tambah Constraint baru untuk integritas data
ALTER TABLE public.users ADD CONSTRAINT users_asal_check CHECK (asal IN ('Warga Asli', 'Perantau'));
ALTER TABLE public.users ADD CONSTRAINT users_status_check CHECK (status IN ('Kawin', 'Belum Kawin'));
ALTER TABLE public.users ADD CONSTRAINT users_jenis_kelamin_check CHECK (jenis_kelamin IN ('Pria', 'Wanita'));
