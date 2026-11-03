-- E46 Logbook ledger schema (Supabase project e46-logbook, ref qyetcwgjqxzewwjktnfr)
-- Anyone can read; only emails in public.editors can add, change or delete.

create table public.editors (
  email text primary key check (email = lower(email)),
  name text not null
);

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  entry_date date not null,
  item text not null check (length(trim(item)) > 0),
  mod text,                                   -- groups payments into one mod on the Upgrades page
  type text not null check (type in ('Purchase','Part','Deposit','Service','Sale')),
  paid_by text not null check (paid_by in ('Felipe','Bugsy','Split')),  -- for a Sale: who received the money
  amount numeric(10,2) not null,              -- sales are stored as negative amounts
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by text default (auth.jwt() ->> 'email'),
  constraint sale_sign check ((type = 'Sale' and amount <= 0) or (type <> 'Sale' and amount >= 0))
);

create table public.planned_purchases (
  id uuid primary key default gen_random_uuid(),
  item text not null check (length(trim(item)) > 0),
  notes text,
  est_cost numeric(10,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by text default (auth.jwt() ->> 'email')
);

create schema if not exists private;
create or replace function private.is_editor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.editors where email = lower(auth.jwt() ->> 'email'));
$$;

create or replace function public.touch_row() returns trigger language plpgsql set search_path = public as $$
begin new.updated_at := now(); new.updated_by := auth.jwt() ->> 'email'; return new; end $$;
create trigger ledger_touch before update on public.ledger_entries for each row execute function public.touch_row();
create trigger planned_touch before update on public.planned_purchases for each row execute function public.touch_row();

alter table public.editors enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.planned_purchases enable row level security;

create policy "editors can see the editor list" on public.editors for select to authenticated using ((select private.is_editor()));
create policy "anyone can read the ledger" on public.ledger_entries for select to anon, authenticated using (true);
create policy "editors add entries" on public.ledger_entries for insert to authenticated with check ((select private.is_editor()));
create policy "editors change entries" on public.ledger_entries for update to authenticated using ((select private.is_editor())) with check ((select private.is_editor()));
create policy "editors remove entries" on public.ledger_entries for delete to authenticated using ((select private.is_editor()));
create policy "anyone can read planned" on public.planned_purchases for select to anon, authenticated using (true);
create policy "editors add planned" on public.planned_purchases for insert to authenticated with check ((select private.is_editor()));
create policy "editors change planned" on public.planned_purchases for update to authenticated using ((select private.is_editor())) with check ((select private.is_editor()));
create policy "editors remove planned" on public.planned_purchases for delete to authenticated using ((select private.is_editor()));

-- To let someone else edit: insert into public.editors (email, name) values ('name@example.com', 'Name');

-- Issues, baseline service items and notes (added 3 Nov 2026). Same access rules as the ledger.
create table public.issues (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) > 0),
  source text, notes text,
  priority text not null default 'warn' check (priority in ('crit','warn','info')),
  resolved boolean not null default false, resolved_on date, resolution text,
  sort int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  updated_by text default (auth.jwt() ->> 'email')
);
create table public.service_items (
  id uuid primary key default gen_random_uuid(),
  item text not null check (length(trim(item)) > 0),
  last_done text,
  status text not null default 'warn' check (status in ('crit','warn','ok')),   -- crit = overdue, warn = check, ok = done
  prev_status text check (prev_status in ('crit','warn')),                       -- restored when a tick is undone
  done_on date, notes text, sort int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  updated_by text default (auth.jwt() ->> 'email')
);
create table public.notes (
  id uuid primary key default gen_random_uuid(),
  body text not null check (length(trim(body)) > 0),
  done boolean not null default false, done_at timestamptz,
  created_at timestamptz not null default now(), created_by text default (auth.jwt() ->> 'email'),
  updated_at timestamptz not null default now(), updated_by text default (auth.jwt() ->> 'email')
);
-- each gets: touch_row trigger, RLS on, public select, editor-only insert/update/delete (see the ledger policies above)

-- 3 Nov 2026: who's on it + area
alter table public.issues add column owner text, add column category text check (category in ('Mechanical','Body & interior'));
alter table public.service_items add column owner text;
-- Signups are limited to rows in public.editors by a before-insert trigger on auth.users (private.only_editors_can_sign_up).

-- 3 Nov 2026: build sheet. Listing equipment plus parts from the ledger; replaces/sold_entry link old parts and sales.
-- status: fitted | pending (bought, not fitted) | removed | sold | spare. Same access rules as the ledger.
create table public.build_items (
  id uuid primary key default gen_random_uuid(),
  section text not null check (section in ('Engine','Drivetrain','Suspension & chassis','Brakes & wheels','Interior','Exterior','Spares')),
  item text not null, status text not null default 'fitted' check (status in ('fitted','pending','removed','sold','spare')),
  source text not null default 'manual' check (source in ('listing','ledger','manual')), evidence text check (evidence in ('yes','part','no')),
  mod text, replaces uuid references public.build_items(id) on delete set null, sold_entry uuid references public.ledger_entries(id) on delete set null,
  fitted_on date, removed_on date, notes text, sort int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), updated_by text default (auth.jwt() ->> 'email')
);
