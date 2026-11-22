-- VSS Admin User Management
-- Run once in Supabase Dashboard -> SQL Editor.
alter table public.vss_id_cards add column if not exists is_blocked boolean not null default false;

create table if not exists public.vss_member_settings (
 id integer primary key check(id=1),
 max_members integer not null default 100000 check(max_members between 1 and 100000)
);
insert into public.vss_member_settings(id,max_members) values(1,100000) on conflict(id) do nothing;
alter table public.vss_member_settings enable row level security;
revoke all on public.vss_member_settings from public,anon,authenticated;

create or replace function public.vss_enforce_member_limit()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_limit integer;
begin
 select max_members into v_limit from public.vss_member_settings where id=1;
 if (select count(*) from public.vss_id_cards) >= coalesce(v_limit,100000) then
  raise exception 'VSS membership limit reached. Please contact the administrator.';
 end if;
 return new;
end; $$;
drop trigger if exists vss_member_limit_guard on public.vss_id_cards;
create trigger vss_member_limit_guard before insert on public.vss_id_cards
for each row execute function public.vss_enforce_member_limit();

create or replace function public.vss_admin_get_member_limit()
returns integer language plpgsql security definer set search_path=public as $$
begin
 if lower(coalesce(auth.jwt()->>'email','')) <> 'info.vsscommunity@gmail.com' then raise exception 'Administrator access required.'; end if;
 return (select max_members from public.vss_member_settings where id=1);
end; $$;

create or replace function public.vss_admin_set_member_limit(p_limit integer)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if lower(coalesce(auth.jwt()->>'email','')) <> 'info.vsscommunity@gmail.com' then raise exception 'Administrator access required.'; end if;
 if p_limit is null or p_limit<1 or p_limit>100000 then raise exception 'User limit must be between 1 and 100000.'; end if;
 if p_limit < (select count(*) from public.vss_id_cards) then raise exception 'The limit cannot be lower than the current number of members.'; end if;
 update public.vss_member_settings set max_members=p_limit where id=1;
 return true;
end; $$;

create or replace function public.vss_admin_add_member(
 p_full_name text,p_branch text,p_semester text,p_phone text,p_email text,p_category text
) returns text language plpgsql security definer set search_path=public as $$
declare v_no text;
begin
 if lower(coalesce(auth.jwt()->>'email','')) <> 'info.vsscommunity@gmail.com' then raise exception 'Administrator access required.'; end if;
 if length(trim(coalesce(p_full_name,'')))<2 or length(trim(coalesce(p_branch,'')))<2
 or length(trim(coalesce(p_semester,'')))=0 or length(regexp_replace(coalesce(p_phone,''),'\D','','g'))<10
 or position('@' in coalesce(p_email,''))<2 or length(trim(coalesce(p_category,'')))=0 then
  raise exception 'Please provide all required member details.';
 end if;
 if exists(select 1 from public.vss_id_cards where lower(trim(email))=lower(trim(p_email))
  or regexp_replace(phone,'\D','','g')=regexp_replace(p_phone,'\D','','g')) then
  raise exception 'This email or mobile number is already registered.';
 end if;
 v_no:='VSS'||lpad(nextval('public.vss_id_number_seq')::text,5,'0');
 insert into public.vss_id_cards(membership_no,full_name,branch,semester,phone,email,membership_category,photo_url,is_blocked)
 values(v_no,trim(p_full_name),trim(p_branch),trim(p_semester),trim(p_phone),lower(trim(p_email)),trim(p_category),'',false);
 return v_no;
exception when unique_violation then raise exception 'This email or mobile number is already registered.';
end; $$;

drop function if exists public.vss_get_member_card_by_number(text,text);
create function public.vss_get_member_card_by_number(p_membership_no text,p_email text)
returns table(membership_no text,full_name text,branch text,semester text,phone text,membership_category text,photo_url text)
language sql stable security definer set search_path=public as $$
 select m.membership_no,m.full_name,m.branch,m.semester,m.phone,m.membership_category,m.photo_url
 from public.vss_id_cards m
 where upper(m.membership_no)=upper(trim(coalesce(p_membership_no,'')))
 and lower(trim(m.email))=lower(trim(coalesce(p_email,''))) and m.is_blocked=false
 limit 1;
$$;

revoke all on function public.vss_admin_get_member_limit() from public;
revoke all on function public.vss_admin_set_member_limit(integer) from public;
revoke all on function public.vss_admin_add_member(text,text,text,text,text,text) from public;
revoke all on function public.vss_get_member_card_by_number(text,text) from public;
grant execute on function public.vss_admin_get_member_limit() to authenticated;
grant execute on function public.vss_admin_set_member_limit(integer) to authenticated;
grant execute on function public.vss_admin_add_member(text,text,text,text,text,text) to authenticated;
grant execute on function public.vss_get_member_card_by_number(text,text) to anon,authenticated;

drop policy if exists "VSS admin can insert members" on public.vss_id_cards;
create policy "VSS admin can insert members" on public.vss_id_cards for insert to authenticated
with check(lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com');
drop policy if exists "VSS admin can delete members" on public.vss_id_cards;
create policy "VSS admin can delete members" on public.vss_id_cards for delete to authenticated
using(lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com');
drop policy if exists "VSS admin can update members" on public.vss_id_cards;
create policy "VSS admin can update members" on public.vss_id_cards for update to authenticated
using(lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com')
with check(lower(coalesce(auth.jwt()->>'email',''))='info.vsscommunity@gmail.com');
grant select,insert,update,delete on public.vss_id_cards to authenticated;
