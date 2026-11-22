-- VSS public instant ID registration + private admin portal
-- Run this complete script in Supabase SQL Editor.
create extension if not exists pgcrypto;
drop trigger if exists vss_auth_user_created on auth.users;

create table if not exists public.vss_id_cards (
  id uuid primary key default gen_random_uuid(),
  membership_no text not null unique,
  full_name text not null,
  photo_url text not null default '',
  branch text not null,
  semester text not null,
  phone text not null,
  email text not null,
  membership_category text not null,
  created_at timestamptz not null default now()
);
alter table public.vss_id_cards add column if not exists photo_url text not null default '';

create unique index if not exists vss_id_cards_name_unique
  on public.vss_id_cards (lower(regexp_replace(trim(full_name), '\s+', ' ', 'g')));
create unique index if not exists vss_id_cards_email_unique on public.vss_id_cards (lower(trim(email)));
create unique index if not exists vss_id_cards_phone_unique on public.vss_id_cards (regexp_replace(phone, '\D', '', 'g'));

create sequence if not exists public.vss_id_number_seq as integer minvalue 0 maxvalue 99999 start 0 increment 1 no cycle;

drop function if exists public.vss_register_member(text,text,text,text,text,text,text);
create function public.vss_register_member(
 p_full_name text,p_branch text,p_semester text,p_phone text,p_email text,p_category text,p_photo_url text
)
returns table(membership_no text,full_name text,branch text,semester text,membership_category text,photo_url text)
language plpgsql security definer set search_path=public
as $$
declare v_no text; v_phone text;
begin
 if length(trim(coalesce(p_full_name,'')))<2 or length(trim(coalesce(p_branch,'')))<2
 or length(trim(coalesce(p_semester,'')))=0 or length(regexp_replace(coalesce(p_phone,''),'\D','','g'))<10
 or position('@' in coalesce(p_email,''))<2 or length(trim(coalesce(p_category,'')))=0
 or length(trim(coalesce(p_photo_url,'')))=0 then
  raise exception 'Please provide all required details in a valid format.';
 end if;
 v_phone:=regexp_replace(p_phone,'\D','','g');
 if exists(select 1 from public.vss_id_cards m
  where lower(regexp_replace(trim(m.full_name),'\s+',' ','g'))=lower(regexp_replace(trim(p_full_name),'\s+',' ','g'))
  or lower(trim(m.email))=lower(trim(p_email))
  or regexp_replace(m.phone,'\D','','g')=v_phone) then
  raise exception 'A registration already exists with this name, mobile number or email.';
 end if;
 v_no:='VSS'||lpad(nextval('public.vss_id_number_seq')::text,5,'0');
 return query insert into public.vss_id_cards as m
 (membership_no,full_name,branch,semester,phone,email,membership_category,photo_url)
 values(v_no,trim(p_full_name),trim(p_branch),trim(p_semester),trim(p_phone),lower(trim(p_email)),trim(p_category),trim(p_photo_url))
 returning m.membership_no,m.full_name,m.branch,m.semester,m.membership_category,m.photo_url;
exception when unique_violation then
 raise exception 'A registration already exists with this name, mobile number or email. Please check your details.';
end; $$;

revoke all on function public.vss_register_member(text,text,text,text,text,text,text) from public;
grant execute on function public.vss_register_member(text,text,text,text,text,text,text) to anon,authenticated;

-- Public photo bucket: anonymous members may upload images; public read enables ID cards to display them.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('vss-member-photos','vss-member-photos',true,3145728,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=3145728,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "VSS members can upload ID photos" on storage.objects;
create policy "VSS members can upload ID photos" on storage.objects
for insert to anon,authenticated with check (bucket_id='vss-member-photos');
grant insert on storage.objects to anon,authenticated;

alter table public.vss_id_cards enable row level security;
drop policy if exists "VSS admin can read members" on public.vss_id_cards;
drop policy if exists "VSS admin can delete members" on public.vss_id_cards;
create policy "VSS admin can read members" on public.vss_id_cards for select to authenticated
 using(lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com');
create policy "VSS admin can delete members" on public.vss_id_cards for delete to authenticated
 using(lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com');
revoke all on public.vss_id_cards from anon;
grant select,delete on public.vss_id_cards to authenticated;
-- Create the admin Auth user separately; the email allowlist above is enforced by RLS.
