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


## Core-member premium gold ID cards

Run `supabase/core-member-premium-cards.sql` once in the Supabase Dashboard SQL Editor. This creates the private request workflow and admin-only approval functions. Only records categorised as **Core Member**, **Core Team**, or **Organizing Committee** can request a premium card. Requests remain pending until the configured VSS administrator approves them. The gold card is shown only after approval.

## VSS Help Assistant

The floating VSS Help Assistant is a curated, on-site FAQ and navigation helper. It can direct visitors to VSS pages and explain common membership, ID-card, events and contact workflows. It does not send chat messages to an external AI service.
