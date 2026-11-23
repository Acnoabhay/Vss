-- VSS event gallery: store one public gallery image with each event.
-- Run once in Supabase Dashboard -> SQL Editor.
alter table public.vss_events
  add column if not exists image_url text not null default '';

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('vss-event-gallery','vss-event-gallery',true,8388608,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public=true,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists "VSS public can view event gallery images" on storage.objects;
create policy "VSS public can view event gallery images"
on storage.objects for select to anon,authenticated
using (bucket_id='vss-event-gallery');

drop policy if exists "VSS admin can upload event gallery images" on storage.objects;
create policy "VSS admin can upload event gallery images"
on storage.objects for insert to authenticated
with check (
 bucket_id='vss-event-gallery'
 and lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com'
);

drop policy if exists "VSS admin can update event gallery images" on storage.objects;
create policy "VSS admin can update event gallery images"
on storage.objects for update to authenticated
using (bucket_id='vss-event-gallery' and lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com')
with check (bucket_id='vss-event-gallery' and lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com');

drop policy if exists "VSS admin can delete event gallery images" on storage.objects;
create policy "VSS admin can delete event gallery images"
on storage.objects for delete to authenticated
using (bucket_id='vss-event-gallery' and lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com');

grant select on storage.objects to anon,authenticated;
grant insert,update,delete on storage.objects to authenticated;
