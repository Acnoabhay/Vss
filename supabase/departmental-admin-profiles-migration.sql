-- VSS departmental admin profile photos and public-safe homepage feed
alter table public.vss_admin_accounts
  add column if not exists photo_url text;

create or replace function public.vss_public_admin_profiles()
returns table (
  user_id uuid,
  full_name text,
  department text,
  photo_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select a.user_id, a.full_name, a.department, a.photo_url
  from public.vss_admin_accounts a
  where a.is_active = true
  order by a.created_at asc;
$$;

revoke all on function public.vss_public_admin_profiles() from public;
grant execute on function public.vss_public_admin_profiles() to anon, authenticated;

-- Allow the Main Admin to update only the profile photo fields.
grant update (photo_url, updated_at) on public.vss_admin_accounts to authenticated;
drop policy if exists "VSS main admin can update departmental admin photos" on public.vss_admin_accounts;
create policy "VSS main admin can update departmental admin photos"
on public.vss_admin_accounts for update to authenticated
using (public.vss_is_main_admin())
with check (public.vss_is_main_admin());
