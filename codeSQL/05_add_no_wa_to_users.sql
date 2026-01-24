-- Menambahkan kolom nomor WhatsApp ke tabel users
ALTER TABLE public.users
ADD COLUMN no_wa TEXT;

-- (Opsional) Menambahkan komentar untuk dokumentasi
COMMENT ON COLUMN public.users.no_wa IS 'Nomor WhatsApp aktif pengguna untuk keperluan kontak admin/darurat';
