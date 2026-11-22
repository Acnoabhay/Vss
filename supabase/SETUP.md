# VSS Member ID — Supabase setup

The portal supports account registration, email delivery of the membership number, and sign-in using membership number + password.

## 1. Database
Open Supabase → SQL Editor, paste the complete `supabase/schema.sql` file and run it. This creates the membership table, automatic ID trigger, public verification function, and server-only email cooldown table.

## 2. Authentication URLs
In Authentication → URL Configuration:
- Site URL: `https://acnoabhay.github.io/Vss/`
- Redirect URL: `https://acnoabhay.github.io/Vss/membership.html`

## 3. Edge Function secrets
In Project Settings → Edge Functions → Secrets, ensure these secrets exist:
- `SUPABASE_URL` — project URL
- `SUPABASE_ANON_KEY` — publishable/anon key
- `SUPABASE_SERVICE_ROLE_KEY` — service-role key (server only; never put in GitHub)
- `RESEND_API_KEY` — Resend API key
- `RESEND_FROM_EMAIL` — sender identity on a domain verified in Resend, e.g. `VSS Community <members@your-verified-domain.in>`

Do not share or commit any secret values.

## 4. Deploy Edge Functions
From the repository root, install/use the Supabase CLI, sign in, link the project, then deploy:

```sh
supabase login
supabase link --project-ref aukiryqoqpotjuuqwsec
supabase functions deploy login-by-member-id
supabase functions deploy send-membership-email
```

The `supabase/config.toml` file disables JWT verification for these two endpoints because they must be callable before a user has signed in. Both functions validate their own inputs; login returns only an Auth session and never returns the member's email.

## 5. Test
1. Register a test account using the portal.
2. Check the inbox for the VSS Membership ID email.
3. Confirm the email if Supabase email confirmation is enabled.
4. Sign in using the VSS membership ID and password.
5. Check the member card and public verification.

## Notes
- Resend must have a verified sending domain for delivery to arbitrary member email addresses. Set `RESEND_FROM_EMAIL` to an address on that verified domain.
- The Resend testing sender is not a production sender for arbitrary recipients.
- Membership IDs currently use the `VSS-CGIT-2026-####` prefix. Update the trigger before issuing IDs for a later year.
- Never put the Supabase service-role key or Resend API key in frontend files.
