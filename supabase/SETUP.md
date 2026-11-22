# VSS ID Portal setup

1. Open the Supabase project dashboard: https://supabase.com/dashboard/project/aukiryqoqpotjuuqwsec
2. Open SQL Editor and run the complete `schema.sql` file from this folder.
3. In Authentication → Users → Add user, create and confirm `info.vsscommunity@gmail.com` with a strong private password.
4. Public ID creation: https://acnoabhay.github.io/Vss/membership.html
5. Admin portal: https://acnoabhay.github.io/Vss/admin.html
6. Admin ID: `VSSADMIN`; use the password configured for the Supabase Auth user.

The schema creates a new table and does not delete old member data. Registration requires no email confirmation, OTP or approval. Full name, email and mobile are unique at database level. IDs are `VSS` plus five digits, allocated atomically and never reused. Registration stops after 100,000 IDs have been issued.

Never expose a Supabase service-role/secret key in frontend code. The public pages use only the anon/publishable key.


## Existing member card retrieval

The membership page now includes an **Already have a VSS ID?** section. Members enter their VSS ID and the email address already registered with that ID, receive a one-time verification code by email, and then retrieve their existing card. It does not create or allocate a second ID.

After updating the repository, run the complete updated `supabase/schema.sql` in Supabase SQL Editor so the two secure retrieval RPC functions are installed. Supabase email OTP must be enabled and the project's email delivery configured. The authenticated retrieval function returns a card only when the verified email matches the member record.
