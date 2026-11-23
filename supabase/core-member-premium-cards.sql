-- VSS Core Member Premium Gold ID Cards
-- Run once in Supabase Dashboard -> SQL Editor.
-- Core-card requests are private. Only the configured VSS admin can approve/reject them.

create table if not exists public.vss_core_card_requests (
 membership_no text primary key references public.vss_id_cards(membership_no) on delete cascade,
 requested_role text not null,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 approved_role text,
 requested_at timestamptz not null default now(),
 reviewed_at timestamptz,
 admin_note text
);
alter table public.vss_core_card_requests enable row level security;
revoke all on public.vss_core_card_requests from public,anon,authenticated;

create or replace function public.vss_core_card_request(
 p_membership_no text,p_email text,p_requested_role text
) returns text language plpgsql security definer set search_path=public as $$
declare v_status text;
begin
 if length(trim(coalesce(p_requested_role,'')))<2 or length(trim(p_requested_role))>80 then
  raise exception 'Enter a valid core team role or designation.';
 end if;
 if not exists(select 1 from public.vss_id_cards m
   where upper(m.membership_no)=upper(trim(coalesce(p_membership_no,'')))
   and lower(trim(m.email))=lower(trim(coalesce(p_email,'')))
   and coalesce(m.is_blocked,false)=false) then
  raise exception 'A valid, active VSS membership ID is required to request a Core Member card.';
 end if;
 insert into public.vss_core_card_requests(membership_no,requested_role,status,approved_role,requested_at,reviewed_at,admin_note)
 values(upper(trim(p_membership_no)),trim(p_requested_role),'pending',null,now(),null,null)
 on conflict(membership_no) do update set
  requested_role=excluded.requested_role,
  status=case when public.vss_core_card_requests.status='approved' then 'approved' else 'pending' end,
  approved_role=case when public.vss_core_card_requests.status='approved' then public.vss_core_card_requests.approved_role else null end,
  requested_at=case when public.vss_core_card_requests.status='approved' then public.vss_core_card_requests.requested_at else now() end,
  reviewed_at=case when public.vss_core_card_requests.status='approved' then public.vss_core_card_requests.reviewed_at else null end;
 select status into v_status from public.vss_core_card_requests where membership_no=upper(trim(p_membership_no));
 return v_status;
end; $$;

create or replace function public.vss_core_card_status(p_membership_no text,p_email text)
returns table(status text,requested_role text,approved_role text,reviewed_at timestamptz)
language sql stable security definer set search_path=public as $$
 select r.status,r.requested_role,r.approved_role,r.reviewed_at
 from public.vss_core_card_requests r
 join public.vss_id_cards m on m.membership_no=r.membership_no
 where upper(m.membership_no)=upper(trim(coalesce(p_membership_no,'')))
 and lower(trim(m.email))=lower(trim(coalesce(p_email,'')))
 and coalesce(m.is_blocked,false)=false
 limit 1;
$$;

create or replace function public.vss_core_card_get(p_membership_no text,p_email text)
returns table(membership_no text,full_name text,branch text,semester text,photo_url text,approved_role text,approved_at timestamptz)
language sql stable security definer set search_path=public as $$
 select m.membership_no,m.full_name,m.branch,m.semester,m.photo_url,r.approved_role,r.reviewed_at
 from public.vss_core_card_requests r
 join public.vss_id_cards m on m.membership_no=r.membership_no
 where upper(m.membership_no)=upper(trim(coalesce(p_membership_no,'')))
 and lower(trim(m.email))=lower(trim(coalesce(p_email,'')))
 and coalesce(m.is_blocked,false)=false and r.status='approved'
 limit 1;
$$;

create or replace function public.vss_admin_core_card_requests()
returns table(membership_no text,full_name text,email text,branch text,requested_role text,status text,requested_at timestamptz,approved_role text)
language plpgsql security definer set search_path=public as $$
begin
 if lower(coalesce(auth.jwt()->>'email',''))<>'info.vsscommunity@gmail.com' then
  raise exception 'Administrator access required.';
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
 if lower(coalesce(auth.jwt()->>'email',''))<>'info.vsscommunity@gmail.com' then
  raise exception 'Administrator access required.';
 end if;
 if lower(coalesce(p_decision,'')) not in ('approved','rejected') then
  raise exception 'Invalid review decision.';
 end if;
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

revoke all on function public.vss_core_card_request(text,text,text) from public;
revoke all on function public.vss_core_card_status(text,text) from public;
revoke all on function public.vss_core_card_get(text,text) from public;
revoke all on function public.vss_admin_core_card_requests() from public;
revoke all on function public.vss_admin_review_core_card(text,text,text,text) from public;
grant execute on function public.vss_core_card_request(text,text,text) to anon,authenticated;
grant execute on function public.vss_core_card_status(text,text) to anon,authenticated;
grant execute on function public.vss_core_card_get(text,text) to anon,authenticated;
grant execute on function public.vss_admin_core_card_requests() to authenticated;
grant execute on function public.vss_admin_review_core_card(text,text,text,text) to authenticated;
