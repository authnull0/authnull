-- 078: database roles created from the console, with their grants (AUTH-227; docs/DB-ROLES.md).
--
-- A console-created role is desired state: the grants the console last set (version), and the
-- version the database agent last applied (applied_version). The agent's job queue (076) carries
-- the work: apply_role creates the role if it is missing -- its password staged in the vault, as a
-- rotation's is -- and makes its grants exactly these; drop_role removes it. valid_until, when set,
-- drops the role once it passes (temporary users).
--
-- The role is a managed account (076) from the start, so rotation and reveal work on it as on any
-- other.
--
-- Lives in each org's database. Replayed on every start: idempotent.

CREATE TABLE IF NOT EXISTS did.db_roles (
    org_id          integer     NOT NULL,
    tenant_id       integer     NOT NULL,
    db_host_id      integer     NOT NULL,
    role            text        NOT NULL,
    grants          jsonb       NOT NULL,
    valid_until     timestamptz,
    version         integer     NOT NULL DEFAULT 1,
    applied_version integer     NOT NULL DEFAULT 0,
    state           text        NOT NULL DEFAULT 'creating'
                    CONSTRAINT db_roles_state CHECK (state IN ('creating', 'active', 'failed', 'dropping', 'dropped')),
    failures        integer     NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    detail          text,
    created_by      integer,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_by      integer,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    dropped_at      timestamptz,
    PRIMARY KEY (org_id, db_host_id, role)
);

-- What the agent last applied: the databases a role must be revoked from when its grants move, and
-- dropped from in the end.
ALTER TABLE did.db_roles ADD COLUMN IF NOT EXISTS applied_grants jsonb;

CREATE INDEX IF NOT EXISTS db_roles_tenant ON did.db_roles (org_id, tenant_id, db_host_id);

-- The jobs that carry them: what to apply travels with the job, so a later change does not alter
-- a job already claimed.
ALTER TABLE did.db_agent_jobs ADD COLUMN IF NOT EXISTS payload jsonb;
ALTER TABLE did.db_agent_jobs DROP CONSTRAINT IF EXISTS db_agent_jobs_kind;
ALTER TABLE did.db_agent_jobs ADD CONSTRAINT db_agent_jobs_kind
    CHECK (kind IN ('rotate_password', 'apply_role', 'drop_role', 'apply_policy_role', 'drop_policy_role'));
-- (All kinds, also those added later: migrations replay on every start, and a narrower list here
-- would fail against rows of a later kind.)
