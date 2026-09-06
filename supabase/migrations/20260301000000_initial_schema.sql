-- HumSukhan schema.
--
-- Two design rules run through this file:
--   1. Every row belongs to exactly one user, and row-level security is what
--      enforces that — not application code. A bug in the client must not be
--      able to read another account's transcripts.
--   2. Retention is a column with a maximum, and expiry is enforced by a
--      scheduled job as well as by the app, so material still disappears if
--      the user never opens the app again.

-- ---------------------------------------------------------------- profiles

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  app_language text not null default 'en'
    check (app_language in ('en', 'ur')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.profiles.app_language is
  'Only en and ur. Hindi is never a substitute for Urdu at any layer.';

alter table public.profiles enable row level security;

create policy "profiles are private to their owner"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- A profile row for every new account, so the app never has to create one on
-- a path where it might fail silently.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data ->> 'display_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------- conversations

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text,
  started_at timestamptz not null,
  ended_at timestamptz,
  retention_days integer not null default 7
    check (retention_days between 1 and 15),
  captions jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

comment on column public.conversations.retention_days is
  'Capped at 15 days by the product, and by this constraint.';

create index if not exists conversations_user_started_idx
  on public.conversations (user_id, started_at desc);

alter table public.conversations enable row level security;

create policy "conversations are private to their owner"
  on public.conversations for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------- sessions

create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  session_type text not null default 'meeting'
    check (session_type in ('meeting', 'lecture', 'classroom')),
  caption_language text not null default 'en'
    check (caption_language in ('en', 'ur')),
  started_at timestamptz not null,
  ended_at timestamptz,
  retention_days integer not null default 7
    check (retention_days between 1 and 15),
  captions jsonb not null default '[]'::jsonb,
  insight jsonb,
  created_at timestamptz not null default now()
);

create index if not exists sessions_user_started_idx
  on public.sessions (user_id, started_at desc);

alter table public.sessions enable row level security;

create policy "sessions are private to their owner"
  on public.sessions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- --------------------------------------------------------------- retention

-- Deletes anything past its own retention window.
--
-- Runs server-side so material expires whether or not the app is opened. The
-- client purges too; neither is trusted to be the only one.
create or replace function public.purge_expired()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.conversations
   where started_at + (retention_days || ' days')::interval < now();

  delete from public.sessions
   where started_at + (retention_days || ' days')::interval < now();
$$;

-- Schedule with pg_cron once the extension is enabled on the project:
--   select cron.schedule('humsukhan-purge', '0 3 * * *',
--                        'select public.purge_expired()');
