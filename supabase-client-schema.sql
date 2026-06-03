-- ETERNAILE — Espace Client Supabase
-- À exécuter dans Supabase SQL Editor.
-- Ce schéma correspond au fichier espace-client.html.

create extension if not exists pgcrypto;

create table if not exists public.users (
    id uuid primary key default gen_random_uuid(),
    email text not null unique,
    name text not null default 'Client ETERNAILE',
    status text not null default 'Gratuit' check (status in ('Gratuit', 'Premium')),
    bilan_history text not null default '',
    bilan_heart text not null default '',
    diagnostic jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.suivi_soin (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    soin_id text not null,
    validated boolean not null default false,
    consequence text not null default '',
    guide_message text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, soin_id)
);

create table if not exists public.ancetres (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    name text not null,
    element text not null check (element in ('Terre', 'Eau', 'Feu', 'Vent', 'Ciel Étoilé')),
    positive text not null default '',
    risk text not null default '',
    navigation_key text not null default '',
    created_at timestamptz not null default now()
);

create index if not exists users_email_idx on public.users(email);
create index if not exists suivi_soin_user_id_idx on public.suivi_soin(user_id);
create index if not exists ancetres_user_id_idx on public.ancetres(user_id);

-- Mode MVP GitHub Pages :
-- Pour tester vite avec la clé anon côté navigateur, laissez RLS désactivé.
-- Pour une vraie production privée, activez Supabase Auth + RLS + Edge Function admin.
alter table public.users disable row level security;
alter table public.suivi_soin disable row level security;
alter table public.ancetres disable row level security;
