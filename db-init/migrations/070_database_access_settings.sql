-- 070: what a database login no policy covers gets, per tenant (DB-MFA-HARDENING S9).
--
-- It was always allowed: AuthNull acted only where a policy said to, so installing it protected
-- nothing until every role had a policy, and deleting a policy silently opened the door it had
-- guarded. Each tenant now chooses -- allow (the default, as before), mfa (challenge the person,
-- then allow) or deny -- from the console (internal/database/nopolicy). authn-service reads it
-- when no policy covers a database login.
--
-- No row means allow. Lives in each org's database. Replayed on every start: IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS did.database_access_settings (
    org_id            integer     NOT NULL,
    tenant_id         integer     NOT NULL,
    no_policy_action  text        NOT NULL DEFAULT 'allow'
                      CHECK (no_policy_action IN ('allow', 'mfa', 'deny')),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        integer,
    PRIMARY KEY (org_id, tenant_id)
);
