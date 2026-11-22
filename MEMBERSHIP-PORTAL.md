# VSS Virtual Membership ID Portal

The membership portal is available at `membership.html`. It supports:
- Member registration and sign-in
- Committee-reviewed applications
- Unique membership numbers issued on approval
- Digital ID card with QR code
- PNG download and browser print / Save as PDF
- Public QR/member-number verification
- Committee admin approval, rejection, suspension and reinstatement

## Setup
Follow [Supabase setup instructions](supabase/SETUP.md) and run [the SQL schema](supabase/schema.sql). The project URL and browser-safe anon/publishable key must be configured in `membership.html` before the portal accepts users.

**Important:** This commit installs the portal code and database schema, but does not create/configure a Supabase project or activate membership processing. Those steps require the VSS project owner's Supabase account.
