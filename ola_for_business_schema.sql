-- ============================================================================
-- Ola for Business — Supabase (Postgres) schema  ·  v1.0
-- 4 entities for the Metafore SOR: account · contact · opportunity · case.
-- B2B CRM: corporate ride accounts sold to enterprises (Infosys, TCS, …).
--
-- Conventions: snake_case; id UUID PK; created_at + updated_at TIMESTAMPTZ;
-- FK columns <parent>_id; created_by / last_changed_by are AUDIT ONLY (no FK).
-- Lifecycle handled via status fields (no hard deletes). Parent-before-child.
--
-- NOTE: Metafore Maker generates these tables from the Maker BRD on ingest —
-- this file is a reference / documentation copy, not a required upload step.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------- 1. account (self-referential holding-company hierarchy) ---------
create table account (
    id                  uuid primary key default gen_random_uuid(),
    name                varchar(120) not null,
    type                varchar(20)  check (type in ('Prospect','Customer','Partner')),
    industry            varchar(40),
    account_tier        varchar(20)  check (account_tier in ('Enterprise','MidMarket','SMB')),
    region              varchar(20)  check (region in ('North','South','East','West')),
    billing_city        varchar(80),
    phone               varchar(20),
    website             varchar(255),
    annual_revenue      integer,
    number_of_employees integer,
    active_contracts    integer      not null default 0,        -- roll-up: count of Closed Won
    health_status       varchar(20)  check (health_status in ('Healthy','At-Risk','Critical')),
    gst_number          varchar(15),                            -- tax id for SAP invoicing
    parent_id           uuid references account(id),            -- holding company
    created_by          uuid, last_changed_by uuid,             -- AUDIT ONLY
    created_at          timestamptz  not null default now(),
    updated_at          timestamptz  not null default now()
);

-- ---------- 2. contact (child of account) -----------------------------------
create table contact (
    id            uuid primary key default gen_random_uuid(),
    account_id    uuid not null references account(id),
    first_name    varchar(80),
    last_name     varchar(80) not null,
    title         varchar(80),
    email         varchar(255),                                 -- PII
    phone         varchar(20),                                  -- PII
    mobile_phone  varchar(20),                                  -- PII
    role          varchar(20) check (role in ('Decision Maker','Influencer','Finance','User')),
    is_primary    boolean not null default false,
    created_by uuid, last_changed_by uuid,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

-- ---------- 3. opportunity (child of account) -------------------------------
create table opportunity (
    id                   uuid primary key default gen_random_uuid(),
    account_id           uuid not null references account(id),
    name                 varchar(160) not null,
    amount               integer,                               -- contract value in INR
    stage                varchar(20) not null default 'Prospecting'
                           check (stage in ('Prospecting','Qualification','Proposal','Negotiation','Closed Won','Closed Lost')),
    close_date           date,
    probability          integer check (probability between 0 and 100),
    type                 varchar(20) check (type in ('New Business','Renewal','Upsell')),
    lead_source          varchar(20) check (lead_source in ('Referral','Inbound','Event','Outbound')),
    forecast_category    varchar(20) check (forecast_category in ('Pipeline','Best Case','Commit','Closed','Omitted')),
    number_of_seats      integer,
    contract_term_months integer,
    needs_vp_approval    boolean not null default false,        -- computed: amount > 1 Cr
    approval_status      varchar(20) not null default 'Not Required'
                           check (approval_status in ('Not Required','Pending','Approved','Rejected')),
    created_by uuid, last_changed_by uuid,
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now()
);

-- ---------- 4. case (child of account + contact) ----------------------------
-- "case" is a reserved word in SQL → table name is quoted.
create table "case" (
    id            uuid primary key default gen_random_uuid(),
    case_number   varchar(20) not null unique,
    account_id    uuid not null references account(id),
    contact_id    uuid references contact(id),
    subject       varchar(160) not null,
    description   text,
    status        varchar(20) not null default 'New'
                    check (status in ('New','Working','Escalated','Closed')),
    priority      varchar(10) check (priority in ('Low','Medium','High','Critical')),
    origin        varchar(20) check (origin in ('Email','Phone','Web','Portal')),
    type          varchar(20) check (type in ('Billing','Service','Technical','Onboarding')),
    reason        varchar(20) check (reason in ('Service Outage','Billing Dispute','Onboarding','How-To','Other')),
    sla_deadline  timestamptz,                                  -- set on Critical escalation
    resolved_at   timestamptz,
    created_by uuid, last_changed_by uuid,
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now()
);

-- ---------- Indexes : foreign keys ------------------------------------------
create index idx_account_parent      on account(parent_id);
create index idx_contact_account     on contact(account_id);
create index idx_opportunity_account on opportunity(account_id);
create index idx_case_account        on "case"(account_id);
create index idx_case_contact        on "case"(contact_id);

-- ---------- Indexes : common query / dashboard paths ------------------------
create index idx_account_tier        on account(account_tier);
create index idx_account_region      on account(region);
create index idx_opportunity_stage   on opportunity(stage);
create index idx_opportunity_close   on opportunity(close_date);
create index idx_case_status         on "case"(status);
create index idx_case_priority       on "case"(priority);
