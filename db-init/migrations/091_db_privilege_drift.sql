-- 091: privilege drift on AuthNull-managed roles (DBPAM-44; docs/DB-PRIVILEGE-DRIFT.md).
--
-- AuthNull knows what it granted its own roles -- console-created and just-in-time accounts
-- (db_roles.applied_grants, 078/088) and policies' restricted roles (db_policy_roles, 079) -- and
-- discovery reports what each login holds (db_user.privilege_level, table_privileges; 072/085).
-- A difference made outside AuthNull is drift: privileges added by hand (extra), table privileges
-- taken away (missing), or the role made an administrator (escalated). Each is a finding, open
-- while discovery still sees it, resolved when it no longer does.
--
-- privilege_drift_fix (per tenant, off by default) re-applies a console or just-in-time role's
-- grants when it drifts, which revokes what was added by hand.
--
-- Lives in each org's database. Replayed on every start: idempotent.

CREATE TABLE IF NOT EXISTS did.db_privilege_drift (
    id          bigserial   PRIMARY KEY,
    org_id      integer     NOT NULL,
    tenant_id   integer     NOT NULL,
    db_host_id  integer     NOT NULL,
    role        text        NOT NULL,
    database    text        NOT NULL,
    managed_by  text        NOT NULL CONSTRAINT db_privilege_drift_managed_by CHECK (managed_by IN ('console', 'jit', 'policy')),
    findings    jsonb       NOT NULL,
    status      text        NOT NULL DEFAULT 'open' CONSTRAINT db_privilege_drift_status CHECK (status IN ('open', 'resolved')),
    first_seen  timestamptz NOT NULL DEFAULT now(),
    last_seen   timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    fixed_at    timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS db_privilege_drift_open
    ON did.db_privilege_drift (org_id, db_host_id, role, database) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS db_privilege_drift_tenant ON did.db_privilege_drift (org_id, tenant_id, status);

DO $$
BEGIN
    IF to_regclass('did.database_access_settings') IS NOT NULL THEN
        ALTER TABLE did.database_access_settings ADD COLUMN IF NOT EXISTS privilege_drift_fix boolean NOT NULL DEFAULT false;
    END IF;
END $$;
