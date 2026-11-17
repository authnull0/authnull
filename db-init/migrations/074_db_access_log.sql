-- 074: the database access audit log (AUTH-229).
--
-- Every database login decision: who (the person the connection token names), as which
-- database role, into which database on which host, from where, what was decided and why --
-- the policy, and the MFA challenge when there was one.
--
-- It was not recorded at all. authn-service's DoAuthenticationDatabase answered ProxySQL and
-- logged nothing an auditor could read; did.mfa_push_activity held the push challenges, and
-- every login that was allowed, blocked, refused for a bad token or decided by the no-policy
-- setting left no trace.
--
-- authn-service writes a row here at each answer, in the same transaction as the event it puts
-- in did.siem_outbox (log_type 'database'), so the console and the SIEM see the same events.
-- event_id is shared by both and makes a retried write a no-op. The console reads it through
-- internal/database/accesslog. Rows are kept: this is an audit trail.
--
-- reason_code is one of a fixed set authn-service uses (docs/DB-ACCESS-AUDIT.md); reason is the
-- human sentence beside it.
--
-- Lives in each org's database. Replayed on every start: IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS did.db_access_log (
    id            bigserial   PRIMARY KEY,
    event_id      uuid        NOT NULL UNIQUE,
    org_id        integer     NOT NULL,
    tenant_id     integer     NOT NULL,
    at            timestamptz NOT NULL DEFAULT now(),
    request_id    text,
    user_id       integer,
    email         text,
    db_user       text,
    database_name text,
    db_type       text,
    db_host       text,
    client_ip     text,
    decision      text        NOT NULL CONSTRAINT db_access_log_decision CHECK (decision IN ('allowed', 'denied')),
    reason_code   text        NOT NULL,
    reason        text,
    policy_id     text,
    policy_name   text,
    policy_action text,
    mfa_method    text,
    mfa_status    text,
    challenge_id  bigint
);

CREATE INDEX IF NOT EXISTS db_access_log_tenant_at ON did.db_access_log (org_id, tenant_id, at DESC);
CREATE INDEX IF NOT EXISTS db_access_log_denied ON did.db_access_log (org_id, tenant_id, at DESC) WHERE decision = 'denied';
