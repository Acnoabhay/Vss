# VSS — Vidyarthi Seva Sangathan

Official VSS community website.

## GitHub Pages deployment
The site is deployed from the `main` branch using the GitHub Actions workflow in `.github/workflows/deploy.yml`.

If Pages is not enabled yet, open **Settings → Pages → Build and deployment → Source**, select **GitHub Actions**, and save. The workflow will then publish the site.

The website retains the original VSS content and functionality, with a refreshed navy/blue/gold visual theme, glass transparency, motion effects, and the VSS Community group photo in the hero section.


## VSS Admin Panel and Student Dashboard

The Admin Panel is available at `admin.html`. Members can access the student dashboard through **Membership** by entering their VSS ID and registered email (no OTP).

For an existing Supabase project, run the complete SQL migration in `supabase/dashboard-admin-migration.sql` once in the Supabase SQL Editor. For a new project, run `supabase/schema.sql`.

The migration creates the announcements and events tables, enables public read access only for published content, and allows the authorised VSS administrator account to manage content and correct member details. Keep the Supabase service-role key private; the website uses only the public anon key.
