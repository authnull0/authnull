-- 079: restricted roles follow the approved database policies (docs/DB-POLICY-ROLES.md).
--
-- A database policy's restricted role (an_..., include/authnull_backend_role.h in ProxySQL) holds
-- exactly the policy's privileges; ProxySQL connects to Postgres as it after MFA. These were made
-- by did.database_job_queue jobs written when a policy was approved -- one per IAM user, all
-- carrying one user name, never revoked or dropped. Now the backend works out which restricted
-- roles the approved policies need on each server (did.db_policy_roles), and Claim queues the
-- difference on the agent's queue (076): apply_policy_role, drop_policy_role. The policy's own
-- role becomes a managed account (076), so its password is the vault's.
--
-- A row's role name is its shape (database, policy role, privileges, tables): a policy that
-- changes shape needs a different role, applied while the old one is dropped once nothing needs it.
--
-- Lives in each org's database. Replayed on every start: idempotent.

CREATE TABLE IF NOT EXISTS did.db_policy_roles (
    org_id          integer     NOT NULL,
    tenant_id       integer     NOT NULL,
    db_host_id      integer     NOT NULL,
    role            text        NOT NULL,
    database        text        NOT NULL,
    source_role     text        NOT NULL,
    privileges      jsonb       NOT NULL,
    tables          jsonb       NOT NULL,
    state           text        NOT NULL DEFAULT 'pending'
                    CONSTRAINT db_policy_roles_state CHECK (state IN ('pending', 'active', 'dropping', 'dropped')),
    failures        integer     NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    detail          text,
    applied_at      timestamptz,
    dropped_at      timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, db_host_id, role)
);

CREATE INDEX IF NOT EXISTS db_policy_roles_tenant ON did.db_policy_roles (org_id, tenant_id, db_host_id);

ALTER TABLE did.db_agent_jobs DROP CONSTRAINT IF EXISTS db_agent_jobs_kind;
ALTER TABLE did.db_agent_jobs ADD CONSTRAINT db_agent_jobs_kind
    CHECK (kind IN ('rotate_password', 'apply_role', 'drop_role', 'apply_policy_role', 'drop_policy_role'));

-- The old queue is done: what it was waiting to do follows from the policies now.
DO $$
BEGIN
    IF to_regclass('did.database_job_queue') IS NOT NULL THEN
        UPDATE did.database_job_queue SET status = 'SUPERSEDED', updated_at = now() WHERE status = 'QUEUED';
    END IF;
END $$;
