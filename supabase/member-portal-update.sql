-- VSS member portal: allow members to update their own digital ID.
-- Run this file once in Supabase Dashboard -> SQL Editor.
-- Access uses the existing VSS ID + registered email match; no OTP is used.

drop function if exists public.vss_get_member_card_by_number(text,text);
create function public.vss_get_member_card_by_number(p_membership_no text,p_email text)
returns table(
 membership_no text,full_name text,branch text,semester text,phone text,
 membership_category text,photo_url text
)
language sql
stable
security definer
set search_path=public
as $$
 select m.membership_no,m.full_name,m.branch,m.semester,m.phone,m.membership_category,m.photo_url
 from public.vss_id_cards m
 where upper(m.membership_no)=upper(trim(coalesce(p_membership_no,'')))
   and lower(trim(m.email))=lower(trim(coalesce(p_email,'')))
 limit 1;
$$;
revoke all on function public.vss_get_member_card_by_number(text,text) from public;
grant execute on function public.vss_get_member_card_by_number(text,text) to anon,authenticated;

create or replace function public.vss_update_member_card(
 p_membership_no text,
 p_email text,
 p_full_name text,
 p_branch text,
 p_semester text,
 p_phone text,
 p_category text,
 p_photo_url text default null
)
returns table(
 membership_no text,full_name text,branch text,semester text,phone text,
 membership_category text,photo_url text
)
language plpgsql
security definer
set search_path=public
as $$
declare v_updated public.vss_id_cards%rowtype;
begin
 if length(trim(coalesce(p_membership_no,'')))=0
 or position('@' in coalesce(p_email,''))<2
 or length(trim(coalesce(p_full_name,'')))<2
 or length(trim(coalesce(p_branch,'')))<2
 or length(trim(coalesce(p_semester,'')))=0
 or length(regexp_replace(coalesce(p_phone,''),'\D','','g'))<10
 or length(trim(coalesce(p_category,'')))=0 then
  raise exception 'Please provide all required details in a valid format.';
 end if;

 update public.vss_id_cards as m
 set full_name=trim(p_full_name),
     branch=trim(p_branch),
     semester=trim(p_semester),
     phone=trim(p_phone),
     membership_category=trim(p_category),
     photo_url=coalesce(nullif(trim(coalesce(p_photo_url,'')),''),m.photo_url)
 where upper(m.membership_no)=upper(trim(p_membership_no))
   and lower(trim(m.email))=lower(trim(p_email))
 returning m.* into v_updated;

 if not found then
  raise exception 'VSS ID and registered email do not match.';
 end if;

 return query select v_updated.membership_no,v_updated.full_name,v_updated.branch,
  v_updated.semester,v_updated.phone,v_updated.membership_category,v_updated.photo_url;
exception when unique_violation then
 raise exception 'This mobile number is already registered with another VSS member.';
end;
$$;
revoke all on function public.vss_update_member_card(text,text,text,text,text,text,text,text) from public;
grant execute on function public.vss_update_member_card(text,text,text,text,text,text,text,text) to anon,authenticated;
