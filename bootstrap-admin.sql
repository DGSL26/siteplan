-- Run only after schema.sql has completed and the first user exists in
-- Supabase Authentication > Users. Replace the email and project name below.
with new_project as (
  insert into public.projects (name)
  values ('Belvedere Gardens')
  returning id
)
insert into public.project_members (project_id, user_id, role)
select new_project.id, auth_user.id, 'admin'
from new_project
cross join auth.users as auth_user
where lower(auth_user.email) = lower('REPLACE-WITH-YOUR-LOGIN-EMAIL');

-- Check the result. If zero rows were inserted, confirm the account email and
-- re-run after correcting it (create the project only once).
select p.name, u.email, m.role
from public.project_members m
join public.projects p on p.id = m.project_id
join auth.users u on u.id = m.user_id
where lower(u.email) = lower('REPLACE-WITH-YOUR-LOGIN-EMAIL');
