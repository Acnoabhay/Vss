-- VSS public homepage/member bulletin access
-- Run once in Supabase SQL Editor. Published notices/events are readable publicly;
-- drafts remain visible only to authorized administrators.
grant select on public.vss_announcements to anon, authenticated;
grant select on public.vss_events to anon, authenticated;

drop policy if exists "VSS public can read published announcements" on public.vss_announcements;
create policy "VSS public can read published announcements"
on public.vss_announcements
for select
to anon, authenticated
using (
  is_published = true
  or lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com'
);

drop policy if exists "VSS public can read published events" on public.vss_events;
create policy "VSS public can read published events"
on public.vss_events
for select
to anon, authenticated
using (
  is_published = true
  or lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com'
);
