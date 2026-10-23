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
  created_at timestamptz not null default now(),
  unique(id, project_id)
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
  updated_at timestamptz not null default now(),
  unique(id, project_id),
  foreign key (subcontractor_id, project_id) references public.subcontractors(id, project_id) on delete cascade
);

create table if not exists public.task_dependencies (
  project_id uuid not null references public.projects(id) on delete cascade,
  predecessor_id uuid not null references public.schedule_tasks(id) on delete cascade,
  successor_id uuid not null references public.schedule_tasks(id) on delete cascade,
  lag_days integer not null default 0,
  primary key (predecessor_id, successor_id),
  check (predecessor_id <> successor_id),
  foreign key (predecessor_id, project_id) references public.schedule_tasks(id, project_id) on delete cascade,
  foreign key (successor_id, project_id) references public.schedule_tasks(id, project_id) on delete cascade
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
using (exists (select 1 from public.project_members m where m.project_id=projects.id and m.user_id=(select auth.uid())));
create policy "members read own memberships" on public.project_members for select to authenticated
using (user_id=(select auth.uid()));
create policy "members read subcontractors" on public.subcontractors for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=subcontractors.project_id and m.user_id=(select auth.uid())));
create policy "members edit subcontractors" on public.subcontractors for all to authenticated
using (exists (select 1 from public.project_members m where m.project_id=subcontractors.project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')))
with check (exists (select 1 from public.project_members m where m.project_id=subcontractors.project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')));
create policy "members read tasks" on public.schedule_tasks for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=schedule_tasks.project_id and m.user_id=(select auth.uid())));
create policy "members edit tasks" on public.schedule_tasks for all to authenticated
using (exists (select 1 from public.project_members m where m.project_id=schedule_tasks.project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')))
with check (exists (select 1 from public.project_members m where m.project_id=schedule_tasks.project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')));
create policy "members read dependencies" on public.task_dependencies for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=task_dependencies.project_id and m.user_id=(select auth.uid())));
create policy "members edit dependencies" on public.task_dependencies for all to authenticated
using (exists (select 1 from public.project_members m where m.project_id=task_dependencies.project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')))
with check (exists (select 1 from public.project_members m where m.project_id=task_dependencies.project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')));
create policy "members read issues" on public.schedule_issues for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=schedule_issues.project_id and m.user_id=(select auth.uid())));
create policy "members create issues" on public.schedule_issues for insert to authenticated
with check (exists (select 1 from public.project_members m where m.project_id=schedule_issues.project_id and m.user_id=(select auth.uid())));

grant select on public.projects, public.project_members, public.subcontractors, public.schedule_tasks, public.task_dependencies, public.schedule_issues to authenticated;
grant insert, update, delete on public.subcontractors, public.schedule_tasks, public.task_dependencies to authenticated;
grant insert on public.schedule_issues to authenticated;


-- XML import schema and RPC (also available as import-schedule.sql migration).
-- SitePlan XML import support. Run once in Supabase SQL Editor before using Import XML.
alter table public.schedule_tasks add column if not exists source_uid text;
create unique index if not exists schedule_tasks_project_source_uid_key
  on public.schedule_tasks(project_id, source_uid);

create table if not exists public.schedule_import_warnings (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  successor_source_uid text not null,
  predecessor_source_uid text not null default '',
  source_name text not null default '',
  source_file text not null default '',
  reason text not null,
  created_at timestamptz not null default now()
);
create index if not exists schedule_import_warnings_project_idx
  on public.schedule_import_warnings(project_id, created_at);
alter table public.schedule_import_warnings enable row level security;
drop policy if exists "members read import warnings" on public.schedule_import_warnings;
create policy "members read import warnings" on public.schedule_import_warnings for select to authenticated
using (exists (select 1 from public.project_members m where m.project_id=schedule_import_warnings.project_id and m.user_id=(select auth.uid())));
drop policy if exists "editors manage import warnings" on public.schedule_import_warnings;
create policy "editors manage import warnings" on public.schedule_import_warnings for all to authenticated
using (exists (select 1 from public.project_members m where m.project_id=schedule_import_warnings.project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')))
with check (exists (select 1 from public.project_members m where m.project_id=schedule_import_warnings.project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')));
grant select, insert, update, delete on public.schedule_import_warnings to authenticated;

create or replace function public.import_siteplan_xml(
  p_project_id uuid,
  p_subcontractors jsonb,
  p_tasks jsonb,
  p_dependencies jsonb,
  p_warnings jsonb,
  p_source_file text
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  item jsonb;
  sub_name text;
  sub_id uuid;
  pred_id uuid;
  succ_id uuid;
  source_uid text;
  inserted_tasks integer := 0;
  inserted_deps integer := 0;
  inserted_warnings integer := 0;
begin
  if not exists (
    select 1 from public.project_members m
    where m.project_id=p_project_id and m.user_id=(select auth.uid()) and m.role in ('admin','editor')
  ) then
    raise exception 'Only a project admin or editor can import a schedule.';
  end if;

  for item in select value from jsonb_array_elements(coalesce(p_subcontractors,'[]'::jsonb)) loop
    sub_name := btrim(item #>> '{}');
    if sub_name = '' then continue; end if;
    select s.id into sub_id from public.subcontractors s
      where s.project_id=p_project_id and lower(btrim(s.name))=lower(sub_name) and s.active=true
      order by s.created_at limit 1;
    if sub_id is null then
      insert into public.subcontractors(project_id,name) values(p_project_id,sub_name) returning id into sub_id;
    end if;
    sub_id := null;
  end loop;

  for item in select value from jsonb_array_elements(coalesce(p_tasks,'[]'::jsonb)) loop
    source_uid := item->>'source_uid';
    select s.id into sub_id from public.subcontractors s
      where s.project_id=p_project_id and lower(btrim(s.name))=lower(btrim(item->>'subcontractor_name')) and s.active=true
      order by s.created_at limit 1;
    if sub_id is null then raise exception 'Subcontractor not found for imported task: %', item->>'title'; end if;
    insert into public.schedule_tasks(project_id,subcontractor_id,source_uid,zone,title,planned_start,duration_days,status)
    values(p_project_id,sub_id,source_uid,coalesce(item->>'zone',''),item->>'title',(item->>'planned_start')::date,(item->>'duration_days')::integer,'planned')
    on conflict(project_id,source_uid) do update set subcontractor_id=excluded.subcontractor_id,zone=excluded.zone,title=excluded.title,planned_start=excluded.planned_start,duration_days=excluded.duration_days,updated_at=now()
    returning id into succ_id;
    inserted_tasks := inserted_tasks + 1;
  end loop;

  -- Re-import replaces dependencies attached to the imported Microsoft Project rows.
  delete from public.task_dependencies d
  where d.project_id=p_project_id and (
    d.predecessor_id in (select t.id from public.schedule_tasks t where t.project_id=p_project_id and t.source_uid in (select x.value->>'source_uid' from jsonb_array_elements(coalesce(p_tasks,'[]'::jsonb)) as x(value)))
    or d.successor_id in (select t.id from public.schedule_tasks t where t.project_id=p_project_id and t.source_uid in (select x.value->>'source_uid' from jsonb_array_elements(coalesce(p_tasks,'[]'::jsonb)) as x(value)))
  );
  for item in select value from jsonb_array_elements(coalesce(p_dependencies,'[]'::jsonb)) loop
    select t.id into pred_id from public.schedule_tasks t where t.project_id=p_project_id and t.source_uid=item->>'predecessor_uid';
    select t.id into succ_id from public.schedule_tasks t where t.project_id=p_project_id and t.source_uid=item->>'successor_uid';
    if pred_id is null or succ_id is null then raise exception 'A verified dependency could not be matched to imported work.'; end if;
    insert into public.task_dependencies(project_id,predecessor_id,successor_id,lag_days)
    values(p_project_id,pred_id,succ_id,coalesce((item->>'lag_days')::integer,0));
    inserted_deps := inserted_deps + 1;
  end loop;

  delete from public.schedule_import_warnings w
  where w.project_id=p_project_id and w.successor_source_uid in (select x.value->>'source_uid' from jsonb_array_elements(coalesce(p_tasks,'[]'::jsonb)) as x(value));
  for item in select value from jsonb_array_elements(coalesce(p_warnings,'[]'::jsonb)) loop
    insert into public.schedule_import_warnings(project_id,successor_source_uid,predecessor_source_uid,source_name,source_file,reason)
    values(p_project_id,coalesce(item->>'successor_source_uid','unknown'),coalesce(item->>'predecessor_source_uid',''),coalesce(item->>'source_name',''),coalesce(p_source_file,''),coalesce(item->>'reason','Needs review'));
    inserted_warnings := inserted_warnings + 1;
  end loop;
  return jsonb_build_object('task_count',inserted_tasks,'dependency_count',inserted_deps,'warning_count',inserted_warnings);
end;
$$;
grant execute on function public.import_siteplan_xml(uuid,jsonb,jsonb,jsonb,jsonb,text) to authenticated;

