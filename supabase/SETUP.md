# VSS ID Portal setup

1. Open the Supabase project dashboard: https://supabase.com/dashboard/project/aukiryqoqpotjuuqwsec
2. Open SQL Editor and run the complete `schema.sql` file from this folder.
3. In Authentication → Users → Add user, create and confirm `info.vsscommunity@gmail.com` with a strong private password.
4. Public ID creation: https://acnoabhay.github.io/Vss/membership.html
5. Admin portal: https://acnoabhay.github.io/Vss/admin.html
6. Admin ID: `VSSADMIN`; use the password configured for the Supabase Auth user.

The schema creates a new table and does not delete old member data. Registration requires no email confirmation, OTP or approval. Full name, email and mobile are unique at database level. IDs are `VSS` plus five digits, allocated atomically and never reused. Registration stops after 100,000 IDs have been issued.

Never expose a Supabase service-role/secret key in frontend code. The public pages use only the anon/publishable key.


## Existing member card retrieval (membership number + registered email)

Members enter their VSS membership number and the email address registered to that same membership record. The database returns the card details only when both values match. No email OTP or Resend delivery is used for this retrieval flow.

Run the complete updated `supabase/schema.sql` in Supabase SQL Editor to create/grant the `vss_get_member_card_by_number(text,text)` RPC. This is a public self-service lookup: anyone who knows both a member's ID and registered email can retrieve the card details and photo. Email matching is not identity verification; do not use this flow for sensitive personal information.
