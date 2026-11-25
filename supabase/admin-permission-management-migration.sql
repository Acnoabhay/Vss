-- VSS Main Admin: granular per-account permission controls
-- Run once in Supabase SQL Editor after departmental-admin-migration.sql.
-- Main Admin remains the only account-management authority.

alter table public.vss_admin_accounts drop constraint if exists vss_admin_accounts_department_check;
alter table public.vss_admin_accounts add constraint vss_admin_accounts_department_check
 check (department in ('academic','technical','administration','organizing'));

create table if not exists public.vss_admin_permissions (
 user_id uuid not null references public.vss_admin_accounts(user_id) on delete cascade,
 permission_key text not null,
 granted_by uuid references auth.users(id) on delete set null,
 granted_at timestamptz not null default now(),
 primary key(user_id,permission_key)
);
alter table public.vss_admin_permissions enable row level security;
revoke all on public.vss_admin_permissions from public,anon,authenticated;
grant select on public.vss_admin_permissions to authenticated;
drop policy if exists "VSS Main Admin reads permission grants" on public.vss_admin_permissions;
create policy "VSS Main Admin reads permission grants" on public.vss_admin_permissions
 for select to authenticated using(public.vss_is_main_admin());

create or replace function public.vss_admin_permission_catalog()
returns text[] language sql immutable as $$
 select array[
 'dashboard.view',
 'members.view','members.manage','members.verify','users.manage',
 'notices.view','notices.create','notices.edit','notices.publish','notices.delete',
 'events.view','events.manage','events.publish',
 'gallery.view','gallery.upload','gallery.publish','gallery.delete',
 'corecards.review'
 ]::text[];
$$;

create or replace function public.vss_admin_my_permissions()
returns text[] language sql stable security definer set search_path=public,auth as $$
 select coalesce(array_agg(p.permission_key order by p.permission_key),array[]::text[])
 from public.vss_admin_permissions p
 join public.vss_admin_accounts a on a.user_id=p.user_id and a.is_active=true
 where p.user_id=auth.uid();
$$;
create or replace function public.vss_admin_has_permission(p_key text)
returns boolean language sql stable security definer set search_path=public,auth as $$
 select public.vss_is_main_admin() or exists(
  select 1 from public.vss_admin_permissions p
  join public.vss_admin_accounts a on a.user_id=p.user_id and a.is_active=true
  where p.user_id=auth.uid() and p.permission_key=p_key
 );
$$;
revoke all on function public.vss_admin_permission_catalog() from public;
revoke all on function public.vss_admin_my_permissions() from public;
revoke all on function public.vss_admin_has_permission(text) from public;
grant execute on function public.vss_admin_permission_catalog() to authenticated;
grant execute on function public.vss_admin_my_permissions() to authenticated;
grant execute on function public.vss_admin_has_permission(text) to authenticated;

-- Preserve the existing department access as the initial permission set.
insert into public.vss_admin_permissions(user_id,permission_key)
select a.user_id,p.permission_key
from public.vss_admin_accounts a
cross join lateral unnest(case a.department
 when 'academic' then array['dashboard.view','notices.view','notices.create','notices.edit','notices.publish','notices.delete','events.view','events.manage','events.publish']::text[]
 when 'technical' then array['dashboard.view','gallery.view','gallery.upload','gallery.publish','gallery.delete']::text[]
 when 'administration' then array['dashboard.view','members.view','members.manage','members.verify','users.manage','corecards.review']::text[]
 when 'organizing' then array['dashboard.view','events.view','events.manage','events.publish','gallery.view','gallery.upload','gallery.publish']::text[]
 else array[]::text[] end) as p(permission_key)
on conflict do nothing;

-- Replace the old department-wide restrictive boundaries with individual permission checks.
-- Published content remains publicly readable; private drafts require the matching view permission.
drop policy if exists "VSS academic read boundary vss_announcements" on public.vss_announcements;
drop policy if exists "VSS academic insert boundary vss_announcements" on public.vss_announcements;
drop policy if exists "VSS academic update boundary vss_announcements" on public.vss_announcements;
drop policy if exists "VSS academic delete boundary vss_announcements" on public.vss_announcements;
create policy "VSS permission read announcements" on public.vss_announcements as restrictive for select to authenticated
 using(is_published=true or public.vss_admin_has_permission('notices.view'));
create policy "VSS permission create announcements" on public.vss_announcements as restrictive for insert to authenticated
 with check(public.vss_admin_has_permission('notices.create'));
create policy "VSS permission edit announcements" on public.vss_announcements as restrictive for update to authenticated
 using(public.vss_admin_has_permission('notices.edit') or public.vss_admin_has_permission('notices.publish'))
 with check(public.vss_admin_has_permission('notices.edit') or public.vss_admin_has_permission('notices.publish'));
create policy "VSS permission delete announcements" on public.vss_announcements as restrictive for delete to authenticated
 using(public.vss_admin_has_permission('notices.delete'));

drop policy if exists "VSS academic read boundary vss_events" on public.vss_events;
drop policy if exists "VSS academic insert boundary vss_events" on public.vss_events;
drop policy if exists "VSS academic update boundary vss_events" on public.vss_events;
drop policy if exists "VSS academic delete boundary vss_events" on public.vss_events;
create policy "VSS permission read events" on public.vss_events as restrictive for select to authenticated
 using(is_published=true or public.vss_admin_has_permission('events.view'));
create policy "VSS permission create events" on public.vss_events as restrictive for insert to authenticated
 with check(public.vss_admin_has_permission('events.manage'));
create policy "VSS permission edit events" on public.vss_events as restrictive for update to authenticated
 using(public.vss_admin_has_permission('events.manage') or public.vss_admin_has_permission('events.publish'))
 with check(public.vss_admin_has_permission('events.manage') or public.vss_admin_has_permission('events.publish'));
create policy "VSS permission delete events" on public.vss_events as restrictive for delete to authenticated
 using(public.vss_admin_has_permission('events.manage'));

drop policy if exists "VSS administration read boundary vss_id_cards" on public.vss_id_cards;
drop policy if exists "VSS administration insert boundary vss_id_cards" on public.vss_id_cards;
drop policy if exists "VSS administration update boundary vss_id_cards" on public.vss_id_cards;
drop policy if exists "VSS administration delete boundary vss_id_cards" on public.vss_id_cards;
create policy "VSS permission read members" on public.vss_id_cards as restrictive for select to authenticated
 using(public.vss_admin_has_permission('members.view') or public.vss_admin_has_permission('members.manage') or public.vss_admin_has_permission('users.manage'));
create policy "VSS permission create members" on public.vss_id_cards as restrictive for insert to authenticated
 with check(public.vss_admin_has_permission('members.manage'));
create policy "VSS permission update members" on public.vss_id_cards as restrictive for update to authenticated
 using(public.vss_admin_has_permission('members.manage') or public.vss_admin_has_permission('users.manage'))
 with check(public.vss_admin_has_permission('members.manage') or public.vss_admin_has_permission('users.manage'));
create policy "VSS permission delete members" on public.vss_id_cards as restrictive for delete to authenticated
 using(public.vss_admin_has_permission('members.manage'));

drop policy if exists "VSS technical read boundary vss_gallery_photos" on public.vss_gallery_photos;
drop policy if exists "VSS technical insert boundary vss_gallery_photos" on public.vss_gallery_photos;
drop policy if exists "VSS technical update boundary vss_gallery_photos" on public.vss_gallery_photos;
drop policy if exists "VSS technical delete boundary vss_gallery_photos" on public.vss_gallery_photos;
create policy "VSS permission read gallery" on public.vss_gallery_photos as restrictive for select to authenticated
 using(is_published=true or public.vss_admin_has_permission('gallery.view'));
create policy "VSS permission upload gallery" on public.vss_gallery_photos as restrictive for insert to authenticated
 with check(public.vss_admin_has_permission('gallery.upload'));
create policy "VSS permission edit gallery" on public.vss_gallery_photos as restrictive for update to authenticated
 using(public.vss_admin_has_permission('gallery.publish') or public.vss_admin_has_permission('gallery.upload'))
 with check(public.vss_admin_has_permission('gallery.publish') or public.vss_admin_has_permission('gallery.upload'));
create policy "VSS permission delete gallery" on public.vss_gallery_photos as restrictive for delete to authenticated
 using(public.vss_admin_has_permission('gallery.delete'));

drop policy if exists "VSS enforce technical storage boundary" on storage.objects;
drop policy if exists "VSS enforce technical storage delete boundary" on storage.objects;
create policy "VSS permission storage upload" on storage.objects as restrictive for insert to authenticated
 with check(bucket_id <> 'vss-event-gallery' or public.vss_admin_has_permission('gallery.upload'));
create policy "VSS permission storage delete" on storage.objects as restrictive for delete to authenticated
 using(bucket_id <> 'vss-event-gallery' or public.vss_admin_has_permission('gallery.delete'));

-- Account-management permissions are deliberately not grantable to departmental administrators.

-- These permissive policies let an explicitly granted administrator cross their
-- original department boundary. The restrictive per-action policies above remain
-- the final gate for every read/write operation.
drop policy if exists "VSS permissioned admins announcements access" on public.vss_announcements;
create policy "VSS permissioned admins announcements access" on public.vss_announcements for all to authenticated
 using(public.vss_is_main_admin() or public.vss_admin_has_permission('notices.view') or public.vss_admin_has_permission('notices.create') or public.vss_admin_has_permission('notices.edit') or public.vss_admin_has_permission('notices.publish') or public.vss_admin_has_permission('notices.delete'))
 with check(public.vss_is_main_admin() or public.vss_admin_has_permission('notices.create') or public.vss_admin_has_permission('notices.edit') or public.vss_admin_has_permission('notices.publish'));
drop policy if exists "VSS permissioned admins events access" on public.vss_events;
create policy "VSS permissioned admins events access" on public.vss_events for all to authenticated
 using(public.vss_is_main_admin() or public.vss_admin_has_permission('events.view') or public.vss_admin_has_permission('events.manage') or public.vss_admin_has_permission('events.publish'))
 with check(public.vss_is_main_admin() or public.vss_admin_has_permission('events.manage') or public.vss_admin_has_permission('events.publish'));
drop policy if exists "VSS permissioned admins members access" on public.vss_id_cards;
create policy "VSS permissioned admins members access" on public.vss_id_cards for all to authenticated
 using(public.vss_is_main_admin() or public.vss_admin_has_permission('members.view') or public.vss_admin_has_permission('members.manage') or public.vss_admin_has_permission('users.manage'))
 with check(public.vss_is_main_admin() or public.vss_admin_has_permission('members.manage') or public.vss_admin_has_permission('users.manage'));
drop policy if exists "VSS permissioned admins gallery access" on public.vss_gallery_photos;
create policy "VSS permissioned admins gallery access" on public.vss_gallery_photos for all to authenticated
 using(public.vss_is_main_admin() or public.vss_admin_has_permission('gallery.view') or public.vss_admin_has_permission('gallery.upload') or public.vss_admin_has_permission('gallery.publish') or public.vss_admin_has_permission('gallery.delete'))
 with check(public.vss_is_main_admin() or public.vss_admin_has_permission('gallery.upload') or public.vss_admin_has_permission('gallery.publish'));

-- Member verification returns only the requested matching member record.
create or replace function public.vss_admin_verify_member(p_membership_no text)
returns table(membership_no text,full_name text,branch text,semester text,phone text,email text,membership_category text,created_at timestamptz,is_blocked boolean,photo_url text)
language plpgsql stable security definer set search_path=public as $$
begin
 if not public.vss_is_main_admin() and not public.vss_admin_has_permission('members.verify') then
  raise exception 'Member verification permission required.';
 end if;
 return query select m.membership_no,m.full_name,m.branch,m.semester,m.phone,m.email,m.membership_category,m.created_at,m.is_blocked,m.photo_url
 from public.vss_id_cards m where upper(m.membership_no)=upper(trim(coalesce(p_membership_no,''))) limit 1;
end; $$;
revoke all on function public.vss_admin_verify_member(text) from public;
grant execute on function public.vss_admin_verify_member(text) to authenticated;

-- Storage object policies also need a permissive path for cross-department grants.
drop policy if exists "VSS permissioned admin storage upload" on storage.objects;
create policy "VSS permissioned admin storage upload" on storage.objects for insert to authenticated
 with check(bucket_id='vss-event-gallery' and (public.vss_is_main_admin() or public.vss_admin_has_permission('gallery.upload')));
drop policy if exists "VSS permissioned admin storage delete" on storage.objects;
create policy "VSS permissioned admin storage delete" on storage.objects for delete to authenticated
 using(bucket_id='vss-event-gallery' and (public.vss_is_main_admin() or public.vss_admin_has_permission('gallery.delete')));
