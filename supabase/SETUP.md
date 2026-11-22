# VSS ID Portal setup

1. Open the Supabase project dashboard: https://supabase.com/dashboard/project/aukiryqoqpotjuuqwsec
2. Open SQL Editor and run the complete `schema.sql` file from this folder.
3. In Authentication → Users → Add user, create and confirm `info.vsscommunity@gmail.com` with a strong private password.
4. Public ID creation: https://acnoabhay.github.io/Vss/membership.html
5. Admin portal: https://acnoabhay.github.io/Vss/admin.html
6. Admin ID: `VSSADMIN`; use the password configured for the Supabase Auth user.

The schema creates a new table and does not delete old member data. Registration requires no email confirmation, OTP or approval. Full name, email and mobile are unique at database level. IDs are `VSS` plus five digits, allocated atomically and never reused. Registration stops after 100,000 IDs have been issued.

Never expose a Supabase service-role/secret key in frontend code. The public pages use only the anon/publishable key.


## Existing member card retrieval (email OTP required)

Members enter their VSS ID number and the email address registered with that ID. The portal sends a 6-digit OTP to the registered email. Only after the OTP is verified does the Edge Function return the card details. OTPs expire after 5 minutes and allow up to 5 attempts.

### Install and configure OTP

1. Run the complete updated `supabase/schema.sql` in Supabase SQL Editor. This creates the private OTP table and removes the old public ID-only lookup function.
2. Deploy `supabase/functions/vss-member-otp/index.ts` as an Edge Function named `vss-member-otp` (Supabase CLI: `supabase functions deploy vss-member-otp`).
3. In Supabase → Edge Functions → Secrets, ensure `RESEND_API_KEY` is set. Add `OTP_PEPPER` as a long random secret and `OTP_FROM_EMAIL` as a sender address authorised in your Resend account. Supabase provides `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions.
4. In Resend, verify your sending domain and configure the matching sender address before sending OTPs to all members. The Resend test sender `onboarding@resend.dev` is restricted to the verified test recipient.
5. Test with a real member ID and its registered email. Confirm delivery, correct OTP acceptance, expiry, and ID photo export.

Do not put the Resend API key, OTP pepper, or Supabase service-role key in `membership.html` or any public GitHub file. The public ID-only lookup has been removed; email OTP is required.
