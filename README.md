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
2. In Authentication settings, turn off public sign-ups. Create the first user in **Authentication → Users**.
3. Run `supabase/schema.sql` once in the SQL editor.
4. In `supabase/bootstrap-admin.sql`, replace `REPLACE-WITH-YOUR-LOGIN-EMAIL`, then run it once in the SQL editor. This creates the project and makes that account its admin.
5. Add the project's URL and publishable key to `supabase-config.js`. Never put a service-role or secret key in website code.
6. Publish the files over HTTPS. Sign in with the first user, then add other users through Supabase Authentication and the project membership table. Grant `editor` or `viewer` roles as appropriate.

The current app supports email/password sign-in, shared subcontractor/task loading, creating tasks, changing durations, and simple predecessor links that push downstream dates forward using Monday–Friday workdays. It is still an early implementation: it does not yet manage user invitations in the app, prevent every possible dependency cycle, pull downstream dates earlier after shortening work, export separate subcontractor PDFs, or email schedules. Check the policies and test with non-production accounts before using real programme data.
