-- VSS Virtual Membership ID System
-- Run this entire file in Supabase Dashboard > SQL Editor.
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
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  role text not null default 'member' check (role in ('member','committee_admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_at timestamptz
);

create or replace function public.vss_is_committee_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.vss_members where user_id=auth.uid() and role='committee_admin' and status='approved'); $$;

create or replace function public.vss_create_member()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  insert into public.vss_members(user_id,full_name)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end; $$;

drop trigger if exists vss_auth_user_created on auth.users;
create trigger vss_auth_user_created after insert on auth.users
for each row execute procedure public.vss_create_member();

alter table public.vss_members enable row level security;
drop policy if exists "members read own profile" on public.vss_members;
create policy "members read own profile" on public.vss_members for select to authenticated
using (user_id=auth.uid() or public.vss_is_committee_admin());

-- No direct client INSERT/UPDATE/DELETE policies: privileged fields cannot be self-assigned.
create or replace function public.vss_update_my_profile(
  p_full_name text, p_branch text, p_semester text, p_phone text, p_photo_path text default null
) returns void language plpgsql security definer set search_path=public
as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  update public.vss_members set
    full_name=left(trim(p_full_name),100),
    branch=left(trim(p_branch),80),
    semester=left(trim(p_semester),40),
    phone=left(trim(p_phone),20),
    photo_path=case when p_photo_path is null then photo_path else p_photo_path end,
    updated_at=now()
  where user_id=auth.uid();
end; $$;
grant execute on function public.vss_update_my_profile(text,text,text,text,text) to authenticated;

create or replace function public.vss_review_member(p_user_id uuid, p_decision text)
returns text language plpgsql security definer set search_path=public
as $$
declare v_no text;
begin
  if not public.vss_is_committee_admin() then raise exception 'Committee administrator access required'; end if;
  if p_decision not in ('approve','reject','suspend','reinstate') then raise exception 'Invalid decision'; end if;
  if p_decision='approve' or p_decision='reinstate' then
    update public.vss_members set
      status='approved',
      membership_no=coalesce(membership_no, 'VSS-CGIT-2026-' || lpad(nextval('public.vss_member_seq')::text,4,'0')),
      approved_at=coalesce(approved_at,now()), updated_at=now()
    where user_id=p_user_id and status in ('pending','rejected','suspended')
    returning membership_no into v_no;
  elsif p_decision='reject' then
    update public.vss_members set status='rejected',updated_at=now()
    where user_id=p_user_id and status='pending';
  else
    update public.vss_members set status='suspended',updated_at=now()
    where user_id=p_user_id and status='approved';
  end if;
  if not found then raise exception 'Member not found or status cannot be changed'; end if;
  return coalesce(v_no,'Updated');
end; $$;
grant execute on function public.vss_review_member(uuid,text) to authenticated;

create or replace function public.vss_verify_member(p_membership_no text)
returns table(valid boolean, membership_no text, full_name text, role_label text, branch text, status text)
language sql stable security definer set search_path=public
as $$
  select (m.status='approved'),m.membership_no,m.full_name,
    case when m.role='committee_admin' then 'Committee Administrator' else 'VSS Member' end,
    m.branch,m.status
  from public.vss_members m
  where m.membership_no=upper(trim(p_membership_no))
  limit 1;
$$;
grant execute on function public.vss_verify_member(text) to anon, authenticated;

-- Private member photo bucket. Each member may upload only inside their own UUID folder.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('vss-member-photos','vss-member-photos',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
drop policy if exists "member uploads own photo" on storage.objects;
create policy "member uploads own photo" on storage.objects for insert to authenticated
with check (bucket_id='vss-member-photos' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "member reads own photo" on storage.objects;
create policy "member reads own photo" on storage.objects for select to authenticated
using (bucket_id='vss-member-photos' and ((storage.foldername(name))[1]=auth.uid()::text or public.vss_is_committee_admin()));
