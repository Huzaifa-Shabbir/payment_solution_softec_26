create table if not exists public.customers (
  id text primary key,
  name text not null,
  email text not null,
  phone text not null,
  amount numeric(12, 2) not null check (amount >= 0),
  due_Date date not null,
  status text not null default 'Pending',
  last_Follow_Up_Date date not null,
  is_paid boolean not null default false,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customers'
      and column_name = 'due_Date'
  ) then
    execute 'create index if not exists customers_due_date_idx on public.customers ("due_Date")';
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'customers'
        and column_name = 'is_paid'
    ) then
      execute 'create index if not exists customers_is_paid_due_date_idx on public.customers (is_paid, "due_Date")';
    end if;
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customers'
      and column_name = 'due_date'
  ) then
    execute 'create index if not exists customers_due_date_idx on public.customers (due_date)';
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'customers'
        and column_name = 'is_paid'
    ) then
      execute 'create index if not exists customers_is_paid_due_date_idx on public.customers (is_paid, due_date)';
    end if;
  end if;
end
$$;

alter table public.customers enable row level security;

drop policy if exists "anon can manage customers" on public.customers;

create policy "anon can manage customers"
  on public.customers
  for all
  to anon, authenticated
  using (true)
  with check (true);

alter table public.reminder_logs drop constraint if exists reminder_logs_account_id_fkey;

alter table public.reminder_logs
  add constraint reminder_logs_account_id_fkey
  foreign key (account_id)
  references public.customers (id)
  on delete cascade
  not valid;

