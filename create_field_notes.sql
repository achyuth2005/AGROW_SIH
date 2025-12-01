-- Create field_notes table
create table if not exists public.field_notes (
  id uuid default gen_random_uuid() primary key,
  user_id text not null, -- Changed from uuid to text for Firebase Auth compatibility
  field_id uuid references public.coordinates_quad(id), -- Optional link to a field
  content text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.field_notes enable row level security;

-- Allow public access (matching the pattern used for other tables like coordinates_quad and user_profiles)
create policy "Public access to field notes"
  on public.field_notes for all
  using (true)
  with check (true);
