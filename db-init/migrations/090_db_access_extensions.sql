-- 090: extending a grant in force (docs/DB-ACCESS-REQUESTS.md, "Extending a grant").
--
-- An extension is an access request (080) that names the grant it extends (extends_request_id):
-- the same policy, approvers and checks; approving it moves that grant's end -- its just-in-time
-- account's expiry (088) and the end of its open sessions with it. An approved extension keeps no
-- end of its own (ends_at NULL), so it is never a grant itself.
--
-- db_session_ends carries a new end to the agent for an open ProxySQL session, as
-- db_session_kills (081) carries a kill: queued, handed out with the agent's next session report,
-- done or failed with the report after.
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.db_access_requests ADD COLUMN IF NOT EXISTS extends_request_id uuid;
CREATE INDEX IF NOT EXISTS db_access_requests_extends
    ON did.db_access_requests (org_id, extends_request_id) WHERE extends_request_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS did.db_session_ends (
    id          uuid        PRIMARY KEY,
    org_id      integer     NOT NULL,
    tenant_id   integer     NOT NULL,
    db_host_id  integer     NOT NULL,
    session_id  bigint      NOT NULL,  -- ProxySQL's
    ends_at     timestamptz NOT NULL,
    request_id  uuid        NOT NULL,  -- the grant it extends
    status      text        NOT NULL DEFAULT 'queued'
                CONSTRAINT db_session_ends_status CHECK (status IN ('queued', 'sent', 'done', 'failed')),
    error       text,
    created_at  timestamptz NOT NULL DEFAULT now(),
    sent_at     timestamptz,
    done_at     timestamptz
);
CREATE INDEX IF NOT EXISTS db_session_ends_open ON did.db_session_ends (org_id, db_host_id, status);
