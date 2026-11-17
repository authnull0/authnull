-- 080: just-in-time database access: requests, approvals, grants (AUTH-235; docs/DB-ACCESS-REQUESTS.md).
--
-- A database policy can require approval (actions.approval). authn-service has asked the
-- approvers during the login itself (repository/db_approval.go): a push each, the first answer
-- deciding, all within the push's 60 seconds. This is the other way in: a person asks ahead --
-- for how long, why, under which ticket -- the approvers are pushed and can decide in the console
-- at any time, and an approval is a grant: logins under the policy until ends_at (or, for a
-- policy whose validMinutes is 0, one login). The policy engine's answer to authn-service carries
-- the person's active grant, and ProxySQL ends the session at ends_at.
--
-- Lives in each org's database. Replayed on every start: idempotent.

CREATE TABLE IF NOT EXISTS did.db_access_requests (
    id              uuid        PRIMARY KEY,
    org_id          integer     NOT NULL,
    tenant_id       integer     NOT NULL,
    policy_id       uuid        NOT NULL,
    requester_id    integer     NOT NULL,
    requester_email text        NOT NULL,
    database        text        NOT NULL,
    role            text        NOT NULL,
    minutes         integer     NOT NULL DEFAULT 0,  -- 0: one sign-in (validMinutes 0)
    justification   text,
    ticket          text,
    approvers       jsonb       NOT NULL,            -- the emails pushed, as resolved at the request
    challenges      jsonb       NOT NULL DEFAULT '[]', -- [{email, challengeId}]
    status          text        NOT NULL DEFAULT 'pending'
                    CONSTRAINT db_access_requests_status
                    CHECK (status IN ('pending', 'approved', 'denied', 'expired', 'cancelled', 'revoked', 'used')),
    decided_by      text,
    decided_at      timestamptz,
    decision_note   text,
    ends_at         timestamptz,
    used_at         timestamptz,
    client_ip       text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS db_access_requests_requester ON did.db_access_requests (org_id, lower(requester_email), policy_id, status);
CREATE INDEX IF NOT EXISTS db_access_requests_pending ON did.db_access_requests (org_id, status) WHERE status = 'pending';
