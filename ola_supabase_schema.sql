-- ============================================================================
-- Ola Electric — Supabase (Postgres) schema  ·  v2.0 (production-real)
-- 10 entities for the Metafore SOR. Scope: CRM records + explainable pricing.
-- Raw GPS / high-frequency telemetry stays in Ola's operational infra.
--
-- Conventions: snake_case; id UUID PK; created_at + updated_at TIMESTAMPTZ;
-- FK columns <parent>_id; created_by / last_changed_by are AUDIT ONLY (no FK).
-- Lifecycle handled via status fields (no hard deletes). Parent-before-child.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------- 1. driver -------------------------------------------------------
create table driver (
    id               uuid primary key default gen_random_uuid(),
    name             varchar(120) not null,
    phone            varchar(15)  not null unique,
    email            varchar(255),
    license_number   varchar(40)  not null unique,
    license_expiry   date,
    operating_city   varchar(80),
    status           varchar(20)  not null default 'Active'
                       check (status in ('Active','Inactive','Suspended','Pending_KYC','Blocked')),
    is_active        boolean      not null default true,        -- currently accepting rides
    kyc_verified     boolean      not null default false,
    rating           numeric(2,1) check (rating between 0 and 5),
    total_trips      integer      not null default 0,
    joined_at        date,
    created_by       uuid, last_changed_by uuid,                -- AUDIT ONLY
    created_at       timestamptz  not null default now(),
    updated_at       timestamptz  not null default now()
);

-- ---------- 2. rider --------------------------------------------------------
create table rider (
    id                     uuid primary key default gen_random_uuid(),
    name                   varchar(120) not null,
    phone                  varchar(15)  not null unique,
    email                  varchar(255),                        -- PII
    home_city              varchar(80),
    rating                 numeric(2,1) check (rating between 0 and 5),
    wallet_balance         numeric(12,2) not null default 0,    -- PII
    default_payment_method varchar(20) check (default_payment_method in ('Cash','Wallet','UPI','Card')),
    total_trips            integer not null default 0,
    is_blocked             boolean not null default false,
    signup_date            date,
    created_by uuid, last_changed_by uuid,
    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

-- ---------- 3. pricing_zone -------------------------------------------------
create table pricing_zone (
    id               uuid primary key default gen_random_uuid(),
    name             varchar(120) not null,
    city             varchar(80)  not null,
    geohash          varchar(20),
    timezone         varchar(40)  not null default 'Asia/Kolkata',
    base_fare        numeric(8,2),
    per_km_rate      numeric(6,2),
    minimum_fare     numeric(8,2),
    regulation_cap   numeric(4,2),                              -- max surge multiplier
    is_active        boolean      not null default true,
    created_by uuid, last_changed_by uuid,
    created_at       timestamptz  not null default now(),
    updated_at       timestamptz  not null default now()
);

-- ---------- 4. vehicle (child of driver) ------------------------------------
create table vehicle (
    id                uuid primary key default gen_random_uuid(),
    driver_id         uuid not null references driver(id),
    registration_no   varchar(20) not null unique,
    vehicle_type      varchar(20) check (vehicle_type in ('EV_Cab','Bike','Auto','Mini')),
    model             varchar(60),
    color             varchar(30),
    manufacture_year  integer check (manufacture_year between 1990 and 2100),
    fuel_type         varchar(20) check (fuel_type in ('Electric','CNG','Petrol')),
    seating_capacity  integer,
    battery_level     numeric(5,2) check (battery_level between 0 and 100),
    is_compliant      boolean not null default false,
    insurance_expiry  date,
    created_by uuid, last_changed_by uuid,
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now()
);

-- ---------- 5. surge_pricing_event (child of pricing_zone) ------------------
create table surge_pricing_event (
    id                 uuid primary key default gen_random_uuid(),
    pricing_zone_id    uuid not null references pricing_zone(id),
    vehicle_type       varchar(20) check (vehicle_type in ('EV_Cab','Bike','Auto','Mini')),
    real_time_demand   integer,
    real_time_supply   integer,
    historical_demand  integer,
    historical_supply  integer,
    pressure_index     numeric(6,2),
    surge_multiplier   numeric(4,2) not null default 1.0,
    effective_from     timestamptz,
    effective_to       timestamptz,
    created_by uuid, last_changed_by uuid,
    created_at         timestamptz not null default now(),      -- decision timestamp
    updated_at         timestamptz not null default now()
);

-- ---------- 6. driver_availability_snapshot ---------------------------------
create table driver_availability_snapshot (
    id               uuid primary key default gen_random_uuid(),
    driver_id        uuid not null references driver(id),
    pricing_zone_id  uuid references pricing_zone(id),
    status           varchar(20) check (status in ('Online','Busy','Offline')),
    latitude         numeric(9,6),                              -- coarse / masked
    longitude        numeric(9,6),
    snapshot_time    timestamptz not null,
    created_by uuid, last_changed_by uuid,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now()
);

-- ---------- 7. trip ---------------------------------------------------------
create table trip (
    id                  uuid primary key default gen_random_uuid(),
    trip_number         varchar(20) not null unique,
    rider_id            uuid references rider(id),
    driver_id           uuid references driver(id),
    vehicle_id          uuid references vehicle(id),
    pricing_event_id    uuid references surge_pricing_event(id),
    status              varchar(20) not null default 'Requested'
                          check (status in ('Requested','Assigned','InProgress','Completed','Cancelled')),
    requested_at        timestamptz not null default now(),
    start_time          timestamptz,
    end_time            timestamptz,
    pickup_address      varchar(255),
    pickup_lat          numeric(9,6),
    pickup_lng          numeric(9,6),
    drop_address        varchar(255),
    drop_lat            numeric(9,6),
    drop_lng            numeric(9,6),
    distance_km         numeric(6,2),
    duration_min        integer,
    base_fare           numeric(12,2),
    surge_multiplier    numeric(4,2),
    fare                numeric(12,2),
    otp                 varchar(6),
    cancelled_at        timestamptz,
    cancellation_reason varchar(120),
    cancelled_by        varchar(10) check (cancelled_by in ('Rider','Driver','System')),
    created_by uuid, last_changed_by uuid,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

-- ---------- 8. payment (child of trip) --------------------------------------
create table payment (
    id               uuid primary key default gen_random_uuid(),
    payment_number   varchar(20) not null unique,
    trip_id          uuid not null references trip(id),
    amount           numeric(12,2) not null,
    currency         char(3) not null default 'INR',
    payment_method   varchar(20) check (payment_method in ('Cash','Wallet','UPI','Card')),
    payment_status   varchar(20) not null default 'Pending'
                       check (payment_status in ('Pending','Success','Failed','Refunded')),
    surge_applied    boolean not null default false,
    gateway          varchar(30),
    transaction_ref  varchar(64),
    refund_amount    numeric(12,2) default 0,
    paid_at          timestamptz,
    created_by uuid, last_changed_by uuid,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now()
);

-- ---------- 9. support_case (child of trip, rider, driver) ------------------
create table support_case (
    id               uuid primary key default gen_random_uuid(),
    case_number      varchar(20) not null unique,
    trip_id          uuid references trip(id),
    rider_id         uuid references rider(id),
    driver_id        uuid references driver(id),
    case_type        varchar(20) check (case_type in ('Safety','Payment','Cancellation','Service')),
    subject          varchar(160),
    description      text,
    channel          varchar(20) check (channel in ('App','Phone','Email','Chat')),
    priority         varchar(10) check (priority in ('Low','Medium','High','Critical')),
    status           varchar(20) not null default 'New'
                       check (status in ('New','InProgress','Closed')),
    resolved_at      timestamptz,
    created_by uuid, last_changed_by uuid,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now()
);

-- ---------- 10. payment_dispute (child of payment, trip, rider) -------------
create table payment_dispute (
    id                 uuid primary key default gen_random_uuid(),
    dispute_number     varchar(20) not null unique,
    payment_id         uuid not null references payment(id),
    trip_id            uuid references trip(id),
    rider_id           uuid references rider(id),
    reason             varchar(40) check (reason in ('Wrong_Fare','Failed_Payment','Refund')),
    description        text,
    status             varchar(20) not null default 'Open'
                         check (status in ('Open','Under_Review','Resolved')),
    resolution_amount  numeric(12,2),
    raised_at          timestamptz not null default now(),
    resolved_at        timestamptz,
    created_by uuid, last_changed_by uuid,
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now()
);

-- ---------- Indexes : foreign keys ------------------------------------------
create index idx_vehicle_driver          on vehicle(driver_id);
create index idx_spe_zone                on surge_pricing_event(pricing_zone_id);
create index idx_das_driver              on driver_availability_snapshot(driver_id);
create index idx_das_zone                on driver_availability_snapshot(pricing_zone_id);
create index idx_trip_rider              on trip(rider_id);
create index idx_trip_driver             on trip(driver_id);
create index idx_trip_vehicle            on trip(vehicle_id);
create index idx_trip_pricing_event      on trip(pricing_event_id);
create index idx_payment_trip            on payment(trip_id);
create index idx_support_case_trip       on support_case(trip_id);
create index idx_support_case_rider      on support_case(rider_id);
create index idx_support_case_driver     on support_case(driver_id);
create index idx_payment_dispute_payment on payment_dispute(payment_id);
create index idx_payment_dispute_trip    on payment_dispute(trip_id);
create index idx_payment_dispute_rider   on payment_dispute(rider_id);

-- ---------- Indexes : common query / dashboard paths ------------------------
create index idx_driver_status           on driver(status);
create index idx_driver_city             on driver(operating_city);
create index idx_rider_city              on rider(home_city);
create index idx_trip_status             on trip(status);
create index idx_trip_requested_at       on trip(requested_at);
create index idx_payment_status          on payment(payment_status);
create index idx_support_case_status     on support_case(status);
create index idx_vehicle_type            on vehicle(vehicle_type);
