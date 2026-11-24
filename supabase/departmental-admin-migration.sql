-- VSS departmental administration and role-based access
-- Run in Supabase Dashboard -> SQL Editor before using departmental accounts.
-- Main administrator remains the existing info.vsscommunity@gmail.com account.

create table if not exists public.vss_admin_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  department text not null check (department in ('academic','technical','administration')),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.vss_admin_accounts enable row level security;
revoke all on public.vss_admin_accounts from public, anon, authenticated;

create or replace function public.vss_is_main_admin()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select lower(coalesce(auth.jwt()->>'email','')) = 'info.vsscommunity@gmail.com';
$$;

create or replace function public.vss_admin_department()
returns text language sql stable security definer set search_path=public,auth as $$
  select a.department
  from public.vss_admin_accounts a
  where a.user_id = auth.uid() and a.is_active = true
  limit 1;
$$;

create or replace function public.vss_is_active_admin()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.vss_is_main_admin() or exists (
    select 1 from public.vss_admin_accounts a
    where a.user_id = auth.uid() and a.is_active = true
  );
$$;

revoke all on function public.vss_is_main_admin() from public;
revoke all on function public.vss_admin_department() from public;
revoke all on function public.vss_is_active_admin() from public;
grant execute on function public.vss_is_main_admin() to authenticated;
grant execute on function public.vss_admin_department() to authenticated;
grant execute on function public.vss_is_active_admin() to authenticated;

-- Main Admin can view account records. Departmental users cannot enumerate or edit admin accounts.
create policy "VSS main admin can view departmental admins"
on public.vss_admin_accounts for select to authenticated
using (public.vss_is_main_admin());

-- Announcements and events belong to the Academic Committee domain.
alter table public.vss_announcements enable row level security;
alter table public.vss_events enable row level security;
drop policy if exists "VSS academic admins manage announcements" on public.vss_announcements;
create policy "VSS academic admins manage announcements"
on public.vss_announcements for all to authenticated
using (public.vss_is_main_admin() or public.vss_admin_department() = 'academic')
with check (public.vss_is_main_admin() or public.vss_admin_department() = 'academic');
drop policy if exists "VSS academic admins manage events" on public.vss_events;
create policy "VSS academic admins manage events"
on public.vss_events for all to authenticated
using (public.vss_is_main_admin() or public.vss_admin_department() = 'academic')
with check (public.vss_is_main_admin() or public.vss_admin_department() = 'academic');

-- Member records and verification belong to Administration.
alter table public.vss_id_cards enable row level security;
drop policy if exists "VSS administration admins manage member records" on public.vss_id_cards;
create policy "VSS administration admins manage member records"
on public.vss_id_cards for all to authenticated
using (public.vss_is_main_admin() or public.vss_admin_department() = 'administration')
with check (public.vss_is_main_admin() or public.vss_admin_department() = 'administration');

-- Gallery content is assigned to the Technical Team.
alter table public.vss_gallery_photos enable row level security;
drop policy if exists "VSS technical admins manage gallery" on public.vss_gallery_photos;
create policy "VSS technical admins manage gallery"
on public.vss_gallery_photos for all to authenticated
using (public.vss_is_main_admin() or public.vss_admin_department() = 'technical')
with check (public.vss_is_main_admin() or public.vss_admin_department() = 'technical');

-- Existing main-admin-only SECURITY DEFINER RPCs retain their main-admin checks.
-- This migration does not grant departmental accounts permission to create admins.
