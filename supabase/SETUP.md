# VSS Virtual Membership ID Portal — Supabase setup

The portal is published as `/membership.html` on the existing GitHub Pages site. Supabase provides authentication, member records, committee approvals, private profile-photo storage and public QR verification.

## 1. Create the Supabase project
Create a project at https://supabase.com/dashboard. Keep the database password private.

## 2. Create the database and security policies
Open **SQL Editor → New query**, paste the complete contents of `supabase/schema.sql`, and run it.

## 3. Configure the website
In `membership.html`, replace:
- `YOUR_SUPABASE_PROJECT_URL` with the Project URL from **Project Settings → API**.
- `YOUR_SUPABASE_ANON_KEY` with the publishable/anon key from **Project Settings → API Keys**.

The anon/publishable key is intended for browser use with the supplied Row Level Security policies. **Never put the service-role key in website code or GitHub.**

## 4. Configure authentication
In **Authentication → URL Configuration**, set the Site URL to:
`https://acnoabhay.github.io/Vss/`

Add this redirect URL:
`https://acnoabhay.github.io/Vss/membership.html`

For first-time testing, disable email confirmation only if appropriate for your membership process; otherwise members must confirm their email before signing in.

## 5. Appoint committee administrators
A project owner must first register the committee member using the portal and confirm their email. Then run this SQL, replacing the email:
```sql
update public.vss_members m
set role='committee_admin', status='approved',
    membership_no=coalesce(m.membership_no,'VSS-CGIT-2026-' || lpad(nextval('public.vss_member_seq')::text,4,'0')),
    approved_at=coalesce(m.approved_at,now())
from auth.users u
where m.user_id=u.id and lower(u.email)=lower('committee.member@example.com');
```
Repeat for each designated committee administrator. Committee admins can approve/reject applications and suspend/reinstate approved members. Regular members cannot grant themselves admin privileges or approve their own membership.

## 6. Test the complete flow
1. Apply with a test member email and confirm the email if confirmation is enabled.
2. Sign in as a committee administrator and approve the application.
3. Sign in as the approved member: the portal should show a unique `VSS-CGIT-2026-####` card and QR code.
4. Download the PNG or use Print / Save PDF.
5. Scan the QR or open its URL. Public verification returns only membership number, name, role label, branch and status — not email or phone.

## Notes
- New membership applications default to **pending**. IDs are assigned only when the committee approves them.
- Member photos are stored in a private Supabase bucket and signed URLs are short-lived.
- Membership status and role are protected from direct member edits by database permissions and RPC functions.
- The ID year prefix is currently 2026; update the prefix in `vss_review_member` before issuing IDs for a later membership year.
- Supabase free-tier quotas and project availability are governed by Supabase. The website itself remains on GitHub Pages.
