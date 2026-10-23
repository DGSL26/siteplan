# SitePlan

SitePlan is a subcontractor-first construction look-ahead scheduler. The current browser preview is still a demonstration: it uses sample data and does not yet save shared schedules.

## Project files

- `index.html` — page structure
- `styles.css` — visual design
- `app.js` — browser interactions
- `supabase/schema.sql` — initial shared database schema and access policies
- `supabase-config.example.js` — browser-safe configuration template

## GitHub and publishing

Create a **private** GitHub repository and upload the project files. A static hosting service can publish the app from that repository whenever you update the `main` branch. The host URL is for using the app; access to schedules must be enforced by Supabase sign-in and database policies. A private GitHub repository does not itself restrict access to a public website deployment.

## Supabase setup

1. Create a separate Supabase project for SitePlan.
2. Run `supabase/schema.sql` in its SQL editor.
3. Add the project's URL and publishable/anon key to `supabase-config.js` (copy from the example). These browser values are intended to be public; never put a service-role or secret key in website code.
4. Create approved user accounts in Supabase Auth. Disable open sign-ups if only invited users should access the app.
5. Connect the app's sign-in and schedule screens to the tables, then confirm RLS policies using separate approved and unapproved accounts before using real schedules.

The SQL is an initial schema, not a production-ready migration: review the rules and add project membership management before loading live data. The current prototype does not yet call Supabase; authentication, persistence, dependency recalculation, PDF generation and emailing still need implementation and verification.
