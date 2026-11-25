# VSS Departmental Admin Setup

The website UI and backend files are committed to the `main` branch. Departmental sign-in is not active until the database migrations and Edge Function are deployed.

## 1. Run the SQL migrations

Open the Supabase SQL Editor for project `aukiryqoqpotjuuqwsec`:

https://supabase.com/dashboard/project/aukiryqoqpotjuuqwsec/sql/new

Run these files in this exact order, copying the complete file contents into the SQL Editor and clicking **Run**:

1. `supabase/departmental-admin-migration.sql`
2. `supabase/departmental-admin-rpc-permissions.sql`
3. `supabase/departmental-admin-designation-migration.sql`

Raw file links:

- https://raw.githubusercontent.com/Acnoabhay/Vss/main/supabase/departmental-admin-migration.sql
- https://raw.githubusercontent.com/Acnoabhay/Vss/main/supabase/departmental-admin-rpc-permissions.sql
- https://raw.githubusercontent.com/Acnoabhay/Vss/main/supabase/departmental-admin-designation-migration.sql

The first migration creates the admin role registry and database access policies. The second enables Administration Dept member-management and premium-card RPCs. The third adds a separate designation field; “Department Administrator” remains the account identity and is not used as the person’s job designation.

## 2. Deploy the account-management Edge Function

From a local clone of this repository with the Supabase CLI installed, run:

```bash
supabase login
supabase link --project-ref aukiryqoqpotjuuqwsec
supabase functions deploy vss-admin-manage
```

The function source is:

https://raw.githubusercontent.com/Acnoabhay/Vss/main/supabase/functions/vss-admin-manage/index.ts

The repository's `supabase/config.toml` configures this function with gateway JWT verification disabled because the function validates the bearer token itself. The function uses the server-side `SUPABASE_SERVICE_ROLE_KEY` environment variable. Never paste that key into `admin.html`, GitHub Pages, or any browser code. Redeploy this function after pulling the latest `main` branch so the Main Admin can edit an administrator’s department and designation.

## 3. Sign in and create accounts

After the migrations and function are deployed, open:

https://acnoabhay.github.io/Vss/admin.html

Sign in with the existing Main Admin ID. Open **Admin accounts** and create each departmental account using its name, email, department and an initial password of at least 12 characters.

Department logins use their assigned email address and password. The Main Admin can disable/activate accounts and reset passwords. Departmental admins cannot access Admin accounts.

## Department boundaries

- Academic Committee VSS: announcements and events.
- Technical Team VSS: homepage photo gallery.
- Administration Dept VSS: member records, member verification, user controls and premium-card requests.
- Main Admin: all workspaces and departmental account management.

If any migration reports an error, stop and resolve it before creating accounts. Do not rerun a partially applied SQL file blindly.
