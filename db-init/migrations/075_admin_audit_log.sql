-- 075: the console's audit trail (AUTH-229): who changed what, when, from where, and whether it
-- worked.
--
-- Nothing recorded console changes. Who switched a database policy from Block to Allow, who set
-- the no-policy action to allow, who issued a proxy credential: none of it could be answered.
-- did.audit_log is a sign-in session log (browser, session length), and did.mfa_device_audit
-- covers Authenticator devices only.
--
-- One row per change request made with a console session (internal/adminaudit): the person,
-- their address and browser, the route, the status, and for chosen objects -- database policies,
-- database settings -- the object before and after. Request bodies are never stored: they carry
-- secrets, and a note says what matters. Refused attempts (401/403) are rows too.
--
-- APPEND-ONLY
--
-- A trigger refuses UPDATE and DELETE, so a row cannot be edited away by the application or by
-- anyone with its database credentials short of dropping the trigger -- which is itself a DDL
-- change a database audit would show. A retention job, when there is one, disables it for its
-- own statement.
--
-- The same event goes to each tenant's SIEM as "Platform Audit Logs" (did.siem_outbox,
-- log_type 'platform').
--
-- Lives in each org's database. Replayed on every start: IF NOT EXISTS / OR REPLACE.

CREATE TABLE IF NOT EXISTS did.admin_audit_log (
    id            bigserial   PRIMARY KEY,
    event_id      uuid        NOT NULL UNIQUE,
    org_id        integer     NOT NULL,
    tenant_id     integer     NOT NULL,
    at            timestamptz NOT NULL DEFAULT now(),
    actor_user_id integer     NOT NULL,
    actor_email   text,
    client_ip     text,
    user_agent    text,
    method        text        NOT NULL,
    route         text        NOT NULL,
    status        integer     NOT NULL,
    outcome       text        NOT NULL CONSTRAINT admin_audit_log_outcome CHECK (outcome IN ('success', 'failure', 'denied')),
    action        text        NOT NULL,
    target_type   text,
    target_id     text,
    changes       jsonb
);

CREATE INDEX IF NOT EXISTS admin_audit_log_tenant_at ON did.admin_audit_log (org_id, tenant_id, at DESC);
CREATE INDEX IF NOT EXISTS admin_audit_log_target ON did.admin_audit_log (org_id, target_type, target_id);

CREATE OR REPLACE FUNCTION did.admin_audit_log_refuse_change() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'did.admin_audit_log is append-only';
END $$;

DROP TRIGGER IF EXISTS admin_audit_log_append_only ON did.admin_audit_log;
CREATE TRIGGER admin_audit_log_append_only BEFORE UPDATE OR DELETE ON did.admin_audit_log
    FOR EACH ROW EXECUTE FUNCTION did.admin_audit_log_refuse_change();
