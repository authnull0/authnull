-- 077: revealing a database role's password (AUTH-232; docs/DB-PASSWORD-VAULT.md).
--
-- Break-glass, as for PAM's local accounts (035, did.password_reveals): an administrator asks, a
-- push goes to their own phone naming the role and the server, and once it is approved the
-- password is shown ONCE. The role is then rotated again soon after (db_managed_accounts.rerotate_at),
-- so a revealed password does not stay valid. Every step is in the audit trail, and the vault logs
-- the release.
--
-- A table of its own rather than did.password_reveals: that one's endpoint_id is an epm_machines
-- id, and a database host id would collide with it.
--
-- Lives in each org's database. Replayed on every start: IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS did.db_password_reveals (
    id           uuid        PRIMARY KEY,
    org_id       integer     NOT NULL,
    tenant_id    integer     NOT NULL,
    db_host_id   integer     NOT NULL,
    role         text        NOT NULL,
    user_id      integer     NOT NULL,
    email        text        NOT NULL,
    challenge_id integer     NOT NULL,
    status       text        NOT NULL DEFAULT 'pending'
                 CONSTRAINT db_password_reveals_status CHECK (status IN ('pending', 'denied', 'expired', 'shown')),
    client_ip    text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    resolved_at  timestamptz
);

CREATE INDEX IF NOT EXISTS db_password_reveals_account ON did.db_password_reveals (org_id, db_host_id, role, created_at DESC);
