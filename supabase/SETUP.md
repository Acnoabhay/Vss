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

The membership page includes an **Already have a VSS ID?** section. Members enter only their existing VSS membership number to retrieve the card. No email address, OTP, or email verification is required. The lookup does not create or allocate a new ID.

After updating the repository, run the complete updated `supabase/schema.sql` in Supabase SQL Editor to install the `vss_get_member_card_by_number` RPC function. **Security note:** this is an intentionally public lookup. Anyone who knows or guesses a membership number can view the card details returned by the function. Do not include private contact information in the returned card data.
