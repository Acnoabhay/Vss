# VSS Instant Member ID Portal

Simple member experience: create account → sign in → get digital ID.

- Name, email and password registration
- Automatic unique VSS ID at account creation
- Login and personal membership card
- QR-based public verification
- Download as PNG or print/save as PDF

Run [the Supabase schema](supabase/schema.sql), then add the Supabase Project URL and browser-safe anon/publishable key to `membership.html`. See [setup guide](supabase/SETUP.md).


## Existing-member portal and digital ID updates

Members can open the portal from the existing-member section by entering their VSS membership number and the email address already registered to that membership. No email OTP is used. After a match, the page opens the member dashboard with the current digital ID and an **Update digital ID** form.

Members can update their name, branch/department, semester/year, mobile number, membership category, and profile photo. The VSS membership number and registered email remain unchanged. The update operation checks the supplied membership number and registered email in Supabase.

### Apply the database update

For an already configured Supabase project, open **Supabase Dashboard → SQL Editor**, paste the complete contents of `supabase/member-portal-update.sql`, and run it once. This recreates the member lookup RPC with the phone field and adds the `vss_update_member_card` RPC. The same SQL is appended to `supabase/schema.sql` for fresh installations.

The website code is deployed from GitHub Pages. After the SQL migration is applied, allow GitHub Pages to finish deploying, then test with a real member ID and its registered email.
