# VSS Member ID — one-time Supabase setup

Member flow: **Create account → Sign in → Get VSS ID.** A unique ID is issued automatically when an account is created. There is no committee approval or extra member application form.

## One-time website-owner setup
1. Create a Supabase project at https://supabase.com/dashboard.
2. Open **SQL Editor → New query**, paste all of `supabase/schema.sql`, and run it.
3. In `membership.html`, replace `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_ANON_KEY` with the Project URL and publishable/anon key from **Project Settings → API**.
4. In **Authentication → URL Configuration**, set Site URL to `https://acnoabhay.github.io/Vss/` and add redirect URL `https://acnoabhay.github.io/Vss/membership.html`.

Never put the service-role key or database password in website code.

## Member experience
- Register with name, email and password.
- The database instantly issues a unique `VSS-CGIT-2026-####` number.
- If email confirmation is enabled, confirm the email and sign in to view the card.
- Download the card as PNG or print/save as PDF.
- Scan the QR code or enter the ID on the public verification form.

The ID year prefix is currently 2026. Update the prefix in the database trigger before issuing IDs for a later year.
