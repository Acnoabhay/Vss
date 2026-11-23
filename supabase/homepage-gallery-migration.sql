-- VSS homepage photo gallery
-- Run this migration once in Supabase Dashboard -> SQL Editor.
create table if not exists public.vss_gallery_photos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  caption text,
  event_id uuid references public.vss_events(id) on delete set null,
  image_url text not null,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists vss_gallery_photos_published_created_idx
  on public.vss_gallery_photos (is_published, created_at desc);
create index if not exists vss_gallery_photos_event_id_idx
  on public.vss_gallery_photos (event_id);
alter table public.vss_gallery_photos enable row level security;
grant select on public.vss_gallery_photos to anon, authenticated;
grant insert, update, delete on public.vss_gallery_photos to authenticated;
drop policy if exists "Public can view published VSS gallery photos" on public.vss_gallery_photos;
create policy "Public can view published VSS gallery photos"
  on public.vss_gallery_photos for select
  using (is_published = true or lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');
drop policy if exists "VSS admin can insert gallery photos" on public.vss_gallery_photos;
create policy "VSS admin can insert gallery photos"
  on public.vss_gallery_photos for insert to authenticated
  with check (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');
drop policy if exists "VSS admin can update gallery photos" on public.vss_gallery_photos;
create policy "VSS admin can update gallery photos"
  on public.vss_gallery_photos for update to authenticated
  using (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com')
  with check (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');
drop policy if exists "VSS admin can delete gallery photos" on public.vss_gallery_photos;
create policy "VSS admin can delete gallery photos"
  on public.vss_gallery_photos for delete to authenticated
  using (lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com');
