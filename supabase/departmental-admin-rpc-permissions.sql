-- VSS departmental access for Administration domain RPCs
-- Run after departmental-admin-migration.sql.
-- These functions deliberately keep Main Admin and Administration Dept as the only callers.

create or replace function public.vss_admin_get_member_limit()
returns integer language plpgsql security definer set search_path=public as $$
begin
 if not public.vss_is_main_admin() and coalesce(public.vss_admin_department(),'') <> 'administration' then
  raise exception 'Administration department access required.';
 end if;
 return (select max_members from public.vss_member_settings where id=1);
end; $$;

create or replace function public.vss_admin_set_member_limit(p_limit integer)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if not public.vss_is_main_admin() and coalesce(public.vss_admin_department(),'') <> 'administration' then
  raise exception 'Administration department access required.';
 end if;
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
 if not public.vss_is_main_admin() and coalesce(public.vss_admin_department(),'') <> 'administration' then
  raise exception 'Administration department access required.';
 end if;
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

create or replace function public.vss_admin_core_card_requests()
returns table(membership_no text,full_name text,email text,branch text,requested_role text,status text,requested_at timestamptz,approved_role text)
language plpgsql security definer set search_path=public as $$
begin
 if not public.vss_is_main_admin() and coalesce(public.vss_admin_department(),'') <> 'administration' then
  raise exception 'Administration department access required.';
 end if;
 return query
 select r.membership_no,m.full_name,m.email,m.branch,r.requested_role,r.status,r.requested_at,r.approved_role
 from public.vss_core_card_requests r join public.vss_id_cards m on m.membership_no=r.membership_no
 order by case r.status when 'pending' then 0 when 'approved' then 1 else 2 end,r.requested_at desc;
end; $$;

create or replace function public.vss_admin_review_core_card(
 p_membership_no text,p_decision text,p_approved_role text default null,p_admin_note text default null
) returns boolean language plpgsql security definer set search_path=public as $$
begin
 if not public.vss_is_main_admin() and coalesce(public.vss_admin_department(),'') <> 'administration' then
  raise exception 'Administration department access required.';
 end if;
 if lower(coalesce(p_decision,'')) not in ('approved','rejected') then raise exception 'Invalid review decision.'; end if;
 if lower(p_decision)='approved' and length(trim(coalesce(p_approved_role,'')))<2 then
  raise exception 'Enter the approved designation before approving.';
 end if;
 update public.vss_core_card_requests
 set status=lower(p_decision),
     approved_role=case when lower(p_decision)='approved' then trim(p_approved_role) else null end,
     reviewed_at=now(),admin_note=left(coalesce(p_admin_note,''),500)
 where upper(membership_no)=upper(trim(coalesce(p_membership_no,'')));
 if not found then raise exception 'Core member request not found.'; end if;
 return true;
end; $$;

revoke all on function public.vss_admin_get_member_limit() from public;
revoke all on function public.vss_admin_set_member_limit(integer) from public;
revoke all on function public.vss_admin_add_member(text,text,text,text,text,text) from public;
revoke all on function public.vss_admin_core_card_requests() from public;
revoke all on function public.vss_admin_review_core_card(text,text,text,text) from public;
grant execute on function public.vss_admin_get_member_limit() to authenticated;
grant execute on function public.vss_admin_set_member_limit(integer) to authenticated;
grant execute on function public.vss_admin_add_member(text,text,text,text,text,text) to authenticated;
grant execute on function public.vss_admin_core_card_requests() to authenticated;
grant execute on function public.vss_admin_review_core_card(text,text,text,text) to authenticated;
