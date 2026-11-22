-- VSS simple instant-issue membership system
create extension if not exists pgcrypto;
create sequence if not exists public.vss_member_seq start 1;

create table if not exists public.vss_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  branch text not null default '',
  semester text not null default '',
  phone text not null default '',
  photo_path text,
  membership_no text unique,
  status text not null default 'approved',
  role text not null default 'member' check (role in ('member','committee_admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_at timestamptz
);

alter table public.vss_members add column if not exists membership_no text;
alter table public.vss_members add column if not exists status text not null default 'approved';
alter table public.vss_members add column if not exists role text not null default 'member';
alter table public.vss_members drop constraint if exists vss_members_status_check;
update public.vss_members set status='approved' where status not in ('approved','suspended');
alter table public.vss_members add constraint vss_members_status_check check(status in ('approved','suspended'));
alter table public.vss_members alter column status set default 'approved';

select setval('public.vss_member_seq',
  coalesce((select max(substring(membership_no from '([0-9]+)$')::bigint) from public.vss_members where membership_no ~ '-[0-9]+$'),0)+1,
  false);

update public.vss_members
set status='approved',
    membership_no=coalesce(membership_no,'VSS-CGIT-2026-' || lpad(nextval('public.vss_member_seq')::text,4,'0')),
    approved_at=coalesce(approved_at,now()),
    updated_at=now()
where membership_no is null or status<>'approved';

alter table public.vss_members alter column membership_no set not null;

create or replace function public.vss_create_member()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  insert into public.vss_members(user_id,full_name,membership_no,status,approved_at)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),
    'VSS-CGIT-2026-' || lpad(nextval('public.vss_member_seq')::text,4,'0'),'approved',now());
  return new;
end; $$;

drop trigger if exists vss_auth_user_created on auth.users;
create trigger vss_auth_user_created after insert on auth.users
for each row execute procedure public.vss_create_member();

alter table public.vss_members enable row level security;
drop policy if exists "members read own profile" on public.vss_members;
create policy "members read own profile" on public.vss_members for select to authenticated
using (user_id=auth.uid());

create or replace function public.vss_verify_member(p_membership_no text)
returns table(valid boolean, membership_no text, full_name text, role_label text, branch text, status text)
language sql stable security definer set search_path=public
as $$
  select (m.status='approved'),m.membership_no,m.full_name,'VSS Member','CGIT Raipur',m.status
  from public.vss_members m where m.membership_no=upper(trim(p_membership_no)) limit 1;
$$;
grant execute on function public.vss_verify_member(text) to anon, authenticated;
