-- AuthNull AAA server (authnull-aaa): a new RADIUS registry type and the accounting table.
--
-- The registry type `authnull` is treated like `freeradius` everywhere (heartbeat, health,
-- Down/recovered alerts, per-server login counts). 061 created the CHECK inline, so Postgres
-- named it radius_servers_type_check.
--
-- did.aaa_accounting holds TACACS+ and RADIUS accounting records sent by the AAA server.
-- Rows go with their server (ON DELETE CASCADE).
--
-- Safe to replay: constraint is dropped IF EXISTS and re-added; table and indexes are IF NOT EXISTS.

ALTER TABLE did.radius_servers DROP CONSTRAINT IF EXISTS radius_servers_type_check;
ALTER TABLE did.radius_servers ADD CONSTRAINT radius_servers_type_check
    CHECK (type IN ('freeradius', 'nps', 'ise', 'clearpass', 'authnull'));

CREATE TABLE IF NOT EXISTS did.aaa_accounting (
    id               bigserial    PRIMARY KEY,
    org_id           integer      NOT NULL,
    tenant_id        integer      NOT NULL,
    radius_server_id uuid         NOT NULL REFERENCES did.radius_servers(id) ON DELETE CASCADE,
    protocol         varchar(8)   NOT NULL CHECK (protocol IN ('radius', 'tacacs')),
    record_type      varchar(16)  NOT NULL,
    username         varchar(255),
    nas_ip           varchar(64),
    port             varchar(64),
    rem_addr         varchar(255),
    task_id          varchar(64),
    service          varchar(64),
    cmd              text,
    elapsed_sec      bigint,
    av_pairs         jsonb,
    device_time      timestamptz,  -- the device's own clock (Event-Timestamp, start/stop_time); NULL if none or implausible
    received_at      timestamptz  NOT NULL DEFAULT now()  -- when authnull-aaa received the record (its timeMs), not
                                                          -- when it was delivered; now() if missing or implausible
);

CREATE INDEX IF NOT EXISTS aaa_accounting_server_received_idx
    ON did.aaa_accounting (radius_server_id, received_at DESC);
-- lower(username): ListAccounting's user filter is case-insensitive.
CREATE INDEX IF NOT EXISTS aaa_accounting_user_received_idx
    ON did.aaa_accounting (org_id, tenant_id, lower(username), received_at DESC);
CREATE INDEX IF NOT EXISTS aaa_accounting_received_idx
    ON did.aaa_accounting (received_at);

-- Server-computed sha256 of a record's identifying fields: a batch re-sent after a lost reply inserts nothing new.
-- Added after CREATE TABLE so a replay on an already-created table still gets it. Old rows keep NULL (never conflict).
ALTER TABLE did.aaa_accounting ADD COLUMN IF NOT EXISTS dedupe_key varchar(64);
CREATE UNIQUE INDEX IF NOT EXISTS aaa_accounting_dedupe
    ON did.aaa_accounting (radius_server_id, dedupe_key);

-- ListAccounting always filters by org + tenant and sorts by time; the nasIp filter needs its own index.
CREATE INDEX IF NOT EXISTS aaa_accounting_tenant_time_idx
    ON did.aaa_accounting (org_id, tenant_id, received_at DESC);
CREATE INDEX IF NOT EXISTS aaa_accounting_tenant_nas_idx
    ON did.aaa_accounting (org_id, tenant_id, nas_ip, received_at DESC);

-- A device's last login now counts TACACS+ too (deviceActivity: protocol IN ('radius','tacacs')), which
-- 061's `WHERE protocol = 'radius'` partial indexes cannot serve: without these the Network Devices
-- page scans the tenant's whole auth_log once per device. CONCURRENTLY and the leftover cleanup as in 061.
DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT c.relname FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
             JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'did' AND NOT i.indisvalid
               AND c.relname IN ('auth_log_aaa_gateway_idx', 'auth_log_aaa_nas_id_idx')
    LOOP
        EXECUTE format('DROP INDEX did.%I', r.relname);
    END LOOP;
END $$;
CREATE INDEX CONCURRENTLY IF NOT EXISTS auth_log_aaa_gateway_idx
    ON did.auth_log (gateway_id, ts_unix_ms DESC) WHERE protocol IN ('radius', 'tacacs');
CREATE INDEX CONCURRENTLY IF NOT EXISTS auth_log_aaa_nas_id_idx
    ON did.auth_log (lower(service_spn), ts_unix_ms DESC) WHERE protocol IN ('radius', 'tacacs');
