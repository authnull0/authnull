-- 082: database session recording (AUTH-221; docs/DB-SESSION-RECORDING.md).
--
-- A policy with actions.session.record has ProxySQL write each statement of the session to a
-- local spool: its text with secrets masked, whether ProxySQL let it through, rows, duration and
-- error -- never result data. The database agent ships each closed spool file (a 5-second bucket)
-- here and deletes it; a file sent twice adds nothing (bucket + line are unique).
--
-- A recording is one session: ProxySQL's session id on one server, labelled from the login's
-- access-log row (the person, the policy, the access grant) -- the newest allowed login with that
-- session id before the statement. Statements older than the retention are pruned.
--
-- Lives in each org's database. Replayed on every start: idempotent.

CREATE TABLE IF NOT EXISTS did.db_session_recordings (
    id               bigserial   PRIMARY KEY,
    org_id           integer     NOT NULL,
    tenant_id        integer     NOT NULL,
    db_host_id       integer     NOT NULL,
    session_id       bigint      NOT NULL,  -- ProxySQL's
    access_log_id    bigint,                -- the login's did.db_access_log row; NULL when none was found
    person_email     text,
    policy_id        text,
    grant_request_id text,
    db_user          text,
    database         text,
    client           text,
    started_at       timestamptz NOT NULL,  -- its first recorded statement
    last_at          timestamptz NOT NULL,
    statements       integer     NOT NULL DEFAULT 0,
    refused          integer     NOT NULL DEFAULT 0,
    errors           integer     NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS db_session_recordings_key
    ON did.db_session_recordings (org_id, db_host_id, session_id, coalesce(access_log_id, 0));
CREATE INDEX IF NOT EXISTS db_session_recordings_tenant ON did.db_session_recordings (org_id, tenant_id, last_at DESC);

CREATE TABLE IF NOT EXISTS did.db_session_statements (
    id           bigserial   PRIMARY KEY,
    org_id       integer     NOT NULL,
    recording_id bigint      NOT NULL REFERENCES did.db_session_recordings (id) ON DELETE CASCADE,
    db_host_id   integer     NOT NULL,
    bucket       bigint      NOT NULL,  -- the spool file it came in (Unix seconds)
    line         integer     NOT NULL,  -- its line in that file
    at           timestamptz NOT NULL,
    duration_ms  bigint      NOT NULL DEFAULT 0,
    statement    text        NOT NULL,  -- masked by ProxySQL
    allowed      boolean     NOT NULL,
    rows_sent    bigint      NOT NULL DEFAULT 0,
    affected     bigint      NOT NULL DEFAULT 0,
    error        text
);
CREATE UNIQUE INDEX IF NOT EXISTS db_session_statements_line ON did.db_session_statements (org_id, db_host_id, bucket, line);
CREATE INDEX IF NOT EXISTS db_session_statements_recording ON did.db_session_statements (recording_id, at, id);
CREATE INDEX IF NOT EXISTS db_session_statements_at ON did.db_session_statements (org_id, at);
