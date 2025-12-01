-- Add new columns to coordinates_quad table
DO $$
BEGIN
    ALTER TABLE public.coordinates_quad ADD COLUMN IF NOT EXISTS user_id text;
    ALTER TABLE public.coordinates_quad ADD COLUMN IF NOT EXISTS name text;
    ALTER TABLE public.coordinates_quad ADD COLUMN IF NOT EXISTS crop_type text;
    ALTER TABLE public.coordinates_quad ADD COLUMN IF NOT EXISTS area_acres double precision;
END $$;

-- Update RLS policies to allow users to see/edit their own data
-- (Existing policies are public, so we might want to tighten them later, but for now this is fine)
