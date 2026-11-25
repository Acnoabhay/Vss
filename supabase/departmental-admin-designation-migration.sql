-- VSS departmental administrator designations
-- Run once in Supabase SQL Editor after departmental-admin-migration.sql.
alter table public.vss_admin_accounts
  add column if not exists designation text not null default 'Department Administrator';

comment on column public.vss_admin_accounts.designation is
  'Human-assigned job designation. Separate from the Department Administrator account identity.';
