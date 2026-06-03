-- Etern'Aile - Schema Supabase pour plateforme pedagogique
-- A executer dans Supabase SQL Editor apres verification.
-- Objectif : cours en ligne, videos, fichiers, progression eleve et verrouillage.

create extension if not exists "pgcrypto";

create table if not exists public.academy_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null default 'student' check (role in ('student', 'guide', 'admin')),
  phase_actuelle integer not null default 0 check (phase_actuelle between 0 and 4),
  niveau_academie integer not null default 0 check (niveau_academie between 0 and 10),
  bilan_complete boolean not null default false,
  statut_structure text not null default 'Stable' check (statut_structure in ('Critique', 'Stable')),
  score_emotionnel integer not null default 0,
  score_physique integer not null default 0,
  score_mental integer not null default 0,
  score_spirituel integer not null default 0,
  dossier_personnel jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.academy_courses (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  phase_required integer not null default 0 check (phase_required between 0 and 4),
  level_required integer not null default 0 check (level_required between 0 and 10),
  body_order integer check (body_order between 1 and 4),
  position integer not null default 0,
  description text,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.academy_lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.academy_courses(id) on delete cascade,
  title text not null,
  video_url text,
  video_storage_path text,
  content text,
  position integer not null default 0,
  is_preview boolean not null default false,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.academy_resources (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.academy_lessons(id) on delete cascade,
  course_id uuid references public.academy_courses(id) on delete cascade,
  title text not null,
  storage_path text not null,
  file_type text not null default 'pdf',
  created_at timestamptz not null default now(),
  constraint resource_scope check (lesson_id is not null or course_id is not null)
);

create table if not exists public.academy_enrollments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  course_id uuid not null references public.academy_courses(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'paused', 'completed')),
  created_at timestamptz not null default now(),
  unique (user_id, course_id)
);

create table if not exists public.academy_lesson_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.academy_profiles(id) on delete cascade,
  lesson_id uuid not null references public.academy_lessons(id) on delete cascade,
  completed boolean not null default false,
  completed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, lesson_id)
);

create or replace function public.is_academy_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.academy_profiles
    where id = auth.uid()
      and role in ('guide', 'admin')
  );
$$;

create or replace function public.can_access_course(target_course_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.academy_profiles p
    join public.academy_courses c on c.id = target_course_id
    where p.id = auth.uid()
      and p.bilan_complete = true
      and p.phase_actuelle >= c.phase_required
      and p.niveau_academie >= c.level_required
  ) or public.is_academy_admin();
$$;

alter table public.academy_profiles enable row level security;
alter table public.academy_courses enable row level security;
alter table public.academy_lessons enable row level security;
alter table public.academy_resources enable row level security;
alter table public.academy_enrollments enable row level security;
alter table public.academy_lesson_progress enable row level security;

create policy "Students read own profile"
on public.academy_profiles for select
using (id = auth.uid() or public.is_academy_admin());

create policy "Admins manage profiles"
on public.academy_profiles for all
using (public.is_academy_admin())
with check (public.is_academy_admin());

create policy "Students read published accessible courses"
on public.academy_courses for select
using (is_published = true and public.can_access_course(id));

create policy "Admins manage courses"
on public.academy_courses for all
using (public.is_academy_admin())
with check (public.is_academy_admin());

create policy "Students read accessible lessons"
on public.academy_lessons for select
using (
  is_published = true
  and (is_preview = true or public.can_access_course(course_id))
);

create policy "Admins manage lessons"
on public.academy_lessons for all
using (public.is_academy_admin())
with check (public.is_academy_admin());

create policy "Students read accessible resources"
on public.academy_resources for select
using (
  public.is_academy_admin()
  or exists (
    select 1
    from public.academy_lessons l
    where l.id = academy_resources.lesson_id
      and public.can_access_course(l.course_id)
  )
  or exists (
    select 1
    from public.academy_courses c
    where c.id = academy_resources.course_id
      and public.can_access_course(c.id)
  )
);

create policy "Admins manage resources"
on public.academy_resources for all
using (public.is_academy_admin())
with check (public.is_academy_admin());

create policy "Students read own enrollments"
on public.academy_enrollments for select
using (user_id = auth.uid() or public.is_academy_admin());

create policy "Admins manage enrollments"
on public.academy_enrollments for all
using (public.is_academy_admin())
with check (public.is_academy_admin());

create policy "Students manage own progress"
on public.academy_lesson_progress for all
using (user_id = auth.uid() or public.is_academy_admin())
with check (user_id = auth.uid() or public.is_academy_admin());

-- Buckets recommandes :
-- 1. academy-videos : prive, videos MP4 ou exports Vimeo si besoin.
-- 2. academy-files  : prive, PDF, audios, carnets, supports.
-- Utiliser des signed URLs cote application pour les fichiers prives.
