-- Create coordinates_quad table with direction columns
CREATE TABLE IF NOT EXISTS public.coordinates_quad (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Point 1
    lat1 double precision,
    lat1_dir text, -- 'N' or 'S'
    lon1 double precision,
    lon1_dir text, -- 'E' or 'W'
    
    -- Point 2
    lat2 double precision,
    lat2_dir text,
    lon2 double precision,
    lon2_dir text,
    
    -- Point 3
    lat3 double precision,
    lat3_dir text,
    lon3 double precision,
    lon3_dir text,
    
    -- Point 4
    lat4 double precision,
    lat4_dir text,
    lon4 double precision,
    lon4_dir text,

    inserted_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.coordinates_quad ENABLE ROW LEVEL SECURITY;

-- Allow public access (for now, as per previous pattern)
CREATE POLICY "Public insert access" ON public.coordinates_quad FOR INSERT WITH CHECK (true);
CREATE POLICY "Public select access" ON public.coordinates_quad FOR SELECT USING (true);

-- Create user_profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_profiles (
    user_id text PRIMARY KEY, -- Using text to be flexible with Auth providers, or uuid if strict
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone,
    full_name text,
    email text,
    phone_number text,
    date_of_birth date,
    address text,
    questionnaire_data jsonb,
    avatar_url text
);

-- Add columns if they don't exist (for updates)
DO $$
BEGIN
    ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS full_name text;
    ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS email text;
    ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS phone_number text;
    ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS date_of_birth date;
    ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS address text;
    ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS questionnaire_data jsonb;
    ALTER TABLE public.user_profiles ADD COLUMN IF NOT EXISTS avatar_url text;
END $$;

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Allow public access (simplest for now, or restrict to auth.uid() if preferred)
CREATE POLICY "Public access" ON public.user_profiles FOR ALL USING (true) WITH CHECK (true);

-- STORAGE SETUP
-- Note: Creating buckets via SQL is not always supported directly in all Supabase environments/extensions.
-- If this fails, please create a public bucket named 'profile_avatars' in the Supabase Dashboard.

insert into storage.buckets (id, name, public)
values ('profile_avatars', 'profile_avatars', true)
on conflict (id) do nothing;

-- Storage Policies
create policy "Avatar images are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'profile_avatars' );

create policy "Anyone can upload an avatar."
  on storage.objects for insert
  with check ( bucket_id = 'profile_avatars' );

create policy "Anyone can update an avatar."
  on storage.objects for update
  with check ( bucket_id = 'profile_avatars' );
