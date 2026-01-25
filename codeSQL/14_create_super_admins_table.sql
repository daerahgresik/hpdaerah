-- Create super_admins table
CREATE TABLE public.super_admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL, -- Storing plain/hashed password similarly to users table for this custom auth
    nama TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Insert a default super admin if needed (optional)
-- INSERT INTO public.super_admins (username, password, nama) VALUES ('superadmin', 'password', 'Super Administrator');
