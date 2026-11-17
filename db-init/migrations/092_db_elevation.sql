-- 092: privilege elevation on a person's own database account (docs/DB-ELEVATION.md).
--
-- db_account_owners: an administrator says whose an account is. AuthNull takes the account's
-- password over (076) and only its owner may log in as it, through the proxy.
--
-- db_elevations: an approved request (080) under an elevation policy (database.access_mode =
-- 'elevate') gives each account its requester owns, on every server of the tenant with the
-- policy's database, more for the access window: the policy's role granted to it, or a bundle of
-- the policy's privileges. payload is what the agent's elevate / unelevate jobs carry.
--
--   granting -> active -> revoking -> revoked; granting -> failed (never granted) -> revoked
--
-- Lives in each org's database. Replayed on every start: idempotent.

CREATE TABLE IF NOT EXISTS did.db_account_owners (
    org_id      integer     NOT NULL,
    tenant_id   integer     NOT NULL,
    db_host_id  integer     NOT NULL,
    role        text        NOT NULL,
    owner_email text        NOT NULL,
    set_by      integer,
    set_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, db_host_id, role)
);

CREATE INDEX IF NOT EXISTS db_account_owners_owner ON did.db_account_owners (org_id, owner_email);
CREATE INDEX IF NOT EXISTS db_account_owners_role ON did.db_account_owners (org_id, role);

CREATE TABLE IF NOT EXISTS did.db_elevations (
    id              uuid        PRIMARY KEY,
    org_id          integer     NOT NULL,
    tenant_id       integer     NOT NULL,
    db_host_id      integer     NOT NULL,
    account         text        NOT NULL,
    owner_email     text        NOT NULL,
    request_id      uuid        NOT NULL,
    policy_id       uuid,
    payload         jsonb       NOT NULL,
    state           text        NOT NULL DEFAULT 'granting'
                    CONSTRAINT db_elevations_state CHECK (state IN ('granting', 'active', 'revoking', 'revoked', 'failed')),
    failures        integer     NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    detail          text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    granted_at      timestamptz,
    revoked_at      timestamptz,
    UNIQUE (org_id, db_host_id, account, request_id)
);

CREATE INDEX IF NOT EXISTS db_elevations_open ON did.db_elevations (org_id, state)
    WHERE state IN ('granting', 'active', 'revoking');
CREATE INDEX IF NOT EXISTS db_elevations_request ON did.db_elevations (org_id, request_id);

ALTER TABLE did.db_agent_jobs DROP CONSTRAINT IF EXISTS db_agent_jobs_kind;
ALTER TABLE did.db_agent_jobs ADD CONSTRAINT db_agent_jobs_kind
    CHECK (kind IN ('rotate_password', 'apply_role', 'drop_role', 'apply_policy_role', 'drop_policy_role',
                    'elevate', 'unelevate'));
