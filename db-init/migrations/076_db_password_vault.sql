-- 076: database role passwords managed in the vault (AUTH-232, AUTH-233; docs/DB-PASSWORD-VAULT.md).
--
-- The backend becomes the source of a managed role's password: it generates it, keeps it in the
-- vault (did.vault_secrets, kinds db_password and db_password_staged -- the kind list is owned
-- by 042), and the database agent applies it to the database and to ProxySQL. Staged first,
-- promoted once the agent reports both changed, so a failure halfway leaves the current password
-- current.
--
-- A role belongs to the database server, not to one database: an account is (org, host, role),
-- the host being did.db_hosts.id, which did.db_user.host_id points at.
--
-- Lives in each org's database. Replayed on every start: IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS did.db_managed_accounts (
    org_id       integer     NOT NULL,
    tenant_id    integer     NOT NULL,
    db_host_id   integer     NOT NULL,
    role         text        NOT NULL,
    enabled      boolean     NOT NULL DEFAULT true,
    status       text        NOT NULL DEFAULT 'pending'
                 CONSTRAINT db_managed_accounts_status CHECK (status IN ('pending', 'active', 'rotating', 'failed')),
    rotated_at   timestamptz,
    next_due_at  timestamptz NOT NULL DEFAULT now(),
    rerotate_at  timestamptz,
    last_job_id  uuid,
    failures     integer     NOT NULL DEFAULT 0,
    detail       text,
    created_by   integer,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_by   integer,
    updated_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, db_host_id, role)
);

CREATE INDEX IF NOT EXISTS db_managed_accounts_due
    ON did.db_managed_accounts (org_id, tenant_id, next_due_at) WHERE enabled;

-- The agent's queue, modelled on did.gateway_jobs (023). claimed_by is the install credential
-- (did.db_proxy_credentials.id) holding the claim; the staged password is released only to it,
-- while lease_until is in the future.
CREATE TABLE IF NOT EXISTS did.db_agent_jobs (
    id               uuid        PRIMARY KEY,
    org_id           integer     NOT NULL,
    tenant_id        integer     NOT NULL,
    db_host_id       integer     NOT NULL,
    role             text        NOT NULL,
    kind             text        NOT NULL CONSTRAINT db_agent_jobs_kind CHECK (kind IN ('rotate_password')),
    status           text        NOT NULL DEFAULT 'queued'
                     CONSTRAINT db_agent_jobs_status CHECK (status IN ('queued', 'claimed', 'done', 'failed', 'cancelled')),
    claimed_by       integer,
    lease_until      timestamptz,
    staged_secret_id uuid,
    attempts         integer     NOT NULL DEFAULT 0,
    error            text,
    created_by       integer,
    created_at       timestamptz NOT NULL DEFAULT now(),
    finished_at      timestamptz
);

-- At most one open job per account: a second "rotate now" joins the first.
CREATE UNIQUE INDEX IF NOT EXISTS db_agent_jobs_one_open
    ON did.db_agent_jobs (org_id, db_host_id, role) WHERE status IN ('queued', 'claimed');
CREATE INDEX IF NOT EXISTS db_agent_jobs_queue
    ON did.db_agent_jobs (org_id, tenant_id, db_host_id, created_at) WHERE status = 'queued';
