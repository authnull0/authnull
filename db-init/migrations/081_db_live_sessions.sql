-- 081: live database sessions and killing them (AUTH-230; docs/DB-LIVE-SESSIONS.md).
--
-- The database agent reports, every few seconds, the client sessions open on its ProxySQL
-- (stats_pgsql_processlist: id, user, database, client, how long -- never the query text). The
-- backend keeps them here, labelled with the person, policy and access grant from the login's
-- access-log row -- which ProxySQL's session id now joins -- and ends a row when a report no longer
-- has it. An administrator can kill a session; revoking an access grant kills its sessions. A kill
-- is handed to the agent in the answer to its next report, which runs ProxySQL's
-- PGSQL KILL CONNECTION and says how it went in the report after.
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.db_access_log ADD COLUMN IF NOT EXISTS proxy_session_id bigint;
ALTER TABLE did.db_access_log ADD COLUMN IF NOT EXISTS grant_request_id text;
CREATE INDEX IF NOT EXISTS db_access_log_proxy_session ON did.db_access_log (org_id, proxy_session_id, at DESC)
    WHERE proxy_session_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS did.db_live_sessions (
    id               bigserial   PRIMARY KEY,
    org_id           integer     NOT NULL,
    tenant_id        integer     NOT NULL,
    db_host_id       integer     NOT NULL,
    session_id       bigint      NOT NULL,  -- ProxySQL's
    db_user          text        NOT NULL,  -- as ProxySQL connects: the policy's role or its restricted role
    database         text,
    client           text,
    command          text,
    started_at       timestamptz NOT NULL,
    last_seen        timestamptz NOT NULL DEFAULT now(),
    ended_at         timestamptz,
    person_email     text,
    policy_id        text,
    grant_request_id text,
    access_log_id    bigint     -- the login's did.db_access_log row; one row labels one session
);
CREATE UNIQUE INDEX IF NOT EXISTS db_live_sessions_open ON did.db_live_sessions (org_id, db_host_id, session_id) WHERE ended_at IS NULL;
CREATE INDEX IF NOT EXISTS db_live_sessions_tenant ON did.db_live_sessions (org_id, tenant_id, ended_at);

CREATE TABLE IF NOT EXISTS did.db_session_kills (
    id           uuid        PRIMARY KEY,
    org_id       integer     NOT NULL,
    tenant_id    integer     NOT NULL,
    db_host_id   integer     NOT NULL,
    session_id   bigint      NOT NULL,
    requested_by text        NOT NULL,  -- an administrator's email, or "grant revoked"
    reason       text,
    status       text        NOT NULL DEFAULT 'queued'
                 CONSTRAINT db_session_kills_status CHECK (status IN ('queued', 'sent', 'done', 'failed')),
    error        text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    sent_at      timestamptz,
    done_at      timestamptz
);
CREATE INDEX IF NOT EXISTS db_session_kills_open ON did.db_session_kills (org_id, db_host_id, status) WHERE status IN ('queued', 'sent');

ALTER TABLE did.db_live_sessions ADD COLUMN IF NOT EXISTS access_log_id bigint;
