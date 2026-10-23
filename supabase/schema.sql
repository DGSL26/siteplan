-- Initial SitePlan data model. Run in a new Supabase project only after review.
create extension if not exists pgcrypto;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.project_members (
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'editor' check (role in ('admin','editor','viewer')),
  primary key (project_id, user_id)
);

create table if not exists public.subcontractors (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  name text not null,
  contact_name text,
  email text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.schedule_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  subcontractor_id uuid not null references public.subcontractors(id) on delete cascade,
  zone text not null default '',
  title text not null,
  description text not null default '',
  planned_start date not null,
  duration_days integer not null check (duration_days > 0),
  status text not null default 'planned' check (status in ('planned','in_progress','complete','blocked')),
  actual_finish date,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.task_dependencies (
  project_id uuid not null references public.projects(id) on delete cascade,
  predecessor_id uuid not null references public.schedule_tasks(id) on delete cascade,
  successor_id uuid not null references public.schedule_tasks(id) on delete cascade,
  lag_days integer not null default 0,
  primary key (predecessor_id, successor_id),
  check (predecessor_id <> successor_id)
);

create table if not exists public.schedule_issues (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  issue_date date not null,
  issued_by uuid references auth.users(id),
  issued_at timestamptz not null default now(),
  status text not null default 'draft' check (status in ('draft','issued'))
);

alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.subcontractors enable row level security;
alter table public.schedule_tasks enable row level security;
alter table public.task_dependencies enable row level security;
alter table public.schedule_issues enable row level security;

-- Membership gates all project rows. This initial policy grants project members
-- read/write; role-aware viewer restrictions should be added before live use.
create policy "members read projects" on public.projects for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=id and m.user_id=(select auth.uid())));
create policy "members read own memberships" on public.project_members for select to authenticated
using (user_id=(select auth.uid()));
create policy "members read subcontractors" on public.subcontractors for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())));
create policy "members edit subcontractors" on public.subcontractors for all to authenticated
using (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())))
with check (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())));
create policy "members read tasks" on public.schedule_tasks for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())));
create policy "members edit tasks" on public.schedule_tasks for all to authenticated
using (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())))
with check (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())));
create policy "members read dependencies" on public.task_dependencies for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())));
create policy "members edit dependencies" on public.task_dependencies for all to authenticated
using (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())))
with check (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())));
create policy "members read issues" on public.schedule_issues for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())));
create policy "members create issues" on public.schedule_issues for insert to authenticated
with check (exists (select 1 from public.project_members m where m.project_id=project_id and m.user_id=(select auth.uid())));

grant select on public.projects, public.project_members, public.subcontractors, public.schedule_tasks, public.task_dependencies, public.schedule_issues to authenticated;
grant insert, update, delete on public.subcontractors, public.schedule_tasks, public.task_dependencies to authenticated;
grant insert on public.schedule_issues to authenticated;
