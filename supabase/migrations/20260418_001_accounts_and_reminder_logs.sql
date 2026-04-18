create table if not exists public.accounts (
  id text primary key,
  name text not null,
  email text not null,
  phone text not null,
  amount numeric(12, 2) not null check (amount >= 0),
  due_date date not null,
  is_paid boolean not null default false,
  status text not null default 'Pending',
  last_contact_date date not null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists accounts_due_date_idx on public.accounts (due_date);
create index if not exists accounts_is_paid_due_date_idx on public.accounts (is_paid, due_date);

create table if not exists public.reminder_logs (
  id bigint generated always as identity primary key,
  account_id text not null references public.accounts (id) on delete cascade,
  reminder_type text not null check (reminder_type in ('gentle', 'strong', 'escalation')),
  reminder_day date not null,
  sent_success boolean not null,
  provider_message_id text,
  error_message text,
  created_at timestamptz not null default now(),
  unique (account_id, reminder_type, reminder_day)
);

create index if not exists reminder_logs_account_day_idx
  on public.reminder_logs (account_id, reminder_day);

alter table public.accounts enable row level security;
alter table public.reminder_logs enable row level security;

create policy if not exists "anon can manage accounts"
  on public.accounts
  for all
  to anon, authenticated
  using (true)
  with check (true);

create policy if not exists "anon can read reminder logs"
  on public.reminder_logs
  for select
  to anon, authenticated
  using (true);

create policy if not exists "service role can manage reminder logs"
  on public.reminder_logs
  for all
  to service_role
  using (true)
  with check (true);

