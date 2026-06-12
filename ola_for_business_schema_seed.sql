-- ============================================================================
-- Ola for Business -- SEED-LOAD schema (Postgres / Supabase)  v1.0  [GENERATED]
-- Source of truth: documents/Ola_for_Business_Schema_Spec.json (supabase[]).
-- Regenerate with: py documents/_gen_ddl_from_spec.py  -- do not hand-edit.
--
-- Use this to load the readable-id mock CSVs (ACC001, CON001, ...) directly via
-- Supabase "Upload CSV". id / FK columns are TEXT (not uuid) so seed keys load
-- as-is; otherwise you get ERROR 22P02: invalid input syntax for type uuid.
-- Differences vs canonical: id/FK columns TEXT; no gen_random_uuid() default;
-- created_by / last_changed_by dropped (not in the CSVs).
-- Import order (parents first): account -> contact -> opportunity -> case.
-- ============================================================================

create extension if not exists "pgcrypto";

-- drop child -> parent (safe on empty tables)
drop table if exists "case" cascade;
drop table if exists opportunity cascade;
drop table if exists contact cascade;
drop table if exists account cascade;

-- 1. account
create table account (
    id                  text primary key,
    name                varchar(120) not null,
    type                varchar(20) check (type in ('Prospect','Customer','Partner')),
    industry            varchar(40),
    account_tier        varchar(20) check (account_tier in ('Enterprise','MidMarket','SMB')),
    region              varchar(20) check (region in ('North','South','East','West')),
    billing_city        varchar(80),
    phone               varchar(20),
    website             varchar(255),
    annual_revenue      bigint,
    number_of_employees integer,
    active_contracts    integer not null default 0,
    health_status       varchar(20) check (health_status in ('Healthy','At-Risk','Critical')),
    gst_number          varchar(15),
    parent_id           text references account(id),
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

-- 2. contact
create table contact (
    id           text primary key,
    account_id   text not null references account(id),
    first_name   varchar(80),
    last_name    varchar(80) not null,
    title        varchar(80),
    email        varchar(255),
    phone        varchar(20),
    mobile_phone varchar(20),
    role         varchar(20) check (role in ('Decision Maker','Influencer','Finance','User')),
    is_primary   boolean not null default false,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

-- 3. opportunity
create table opportunity (
    id                   text primary key,
    account_id           text not null references account(id),
    name                 varchar(160) not null,
    amount               bigint,
    stage                varchar(20) not null default 'Prospecting' check (stage in ('Prospecting','Qualification','Proposal','Negotiation','Closed Won','Closed Lost')),
    close_date           date,
    probability          integer check (probability between 0 and 100),
    type                 varchar(20) check (type in ('New Business','Renewal','Upsell')),
    lead_source          varchar(20) check (lead_source in ('Referral','Inbound','Event','Outbound')),
    forecast_category    varchar(20) check (forecast_category in ('Pipeline','Best Case','Commit','Closed','Omitted')),
    number_of_seats      integer,
    contract_term_months integer,
    needs_vp_approval    boolean not null default false,
    approval_status      varchar(20) not null default 'Not Required' check (approval_status in ('Not Required','Pending','Approved','Rejected')),
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now()
);

-- 4. case  -- case is a reserved word in SQL; quote the table name in DDL.
create table "case" (
    id           text primary key,
    case_number  varchar(20) not null unique,
    account_id   text not null references account(id),
    contact_id   text references contact(id),
    subject      varchar(160) not null,
    description  text,
    status       varchar(20) not null default 'New' check (status in ('New','Working','Escalated','Closed')),
    priority     varchar(10) check (priority in ('Low','Medium','High','Critical')),
    origin       varchar(20) check (origin in ('Email','Phone','Web','Portal')),
    type         varchar(20) check (type in ('Billing','Service','Technical','Onboarding')),
    reason       varchar(20) check (reason in ('Service Outage','Billing Dispute','Onboarding','How-To','Other')),
    sla_deadline timestamptz,
    resolved_at  timestamptz,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

-- foreign key indexes
create index idx_account_parent on account(parent_id);
create index idx_contact_account on contact(account_id);
create index idx_opportunity_account on opportunity(account_id);
create index idx_case_account on "case"(account_id);
create index idx_case_contact on "case"(contact_id);

-- query / dashboard indexes
create index idx_account_tier on account(account_tier);
create index idx_account_region on account(region);
create index idx_opportunity_stage on opportunity(stage);
create index idx_opportunity_close on opportunity(close_date);
create index idx_case_status on "case"(status);
create index idx_case_priority on "case"(priority);
