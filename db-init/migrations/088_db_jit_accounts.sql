-- 088: just-in-time database accounts (docs/DB-JIT-ACCOUNTS.md).
--
-- An approved access request (080) gets its own database account on every server of its tenant
-- that has the policy's database: jit_<who>_<request>, holding exactly the policy's privileges,
-- its password in the vault and in ProxySQL, used through the proxy only. It is a console role
-- (078) the backend creates itself: the agent's apply_role / drop_role jobs create and drop it
-- unchanged. jit_request_id ties it to the request; owner_email is the only person who may log in
-- as it; policy_id is the policy version it was approved under.
--
-- policy_fingerprint pins a request to the policy as it was approved: a later edit of the policy's
-- database block (database, role, privileges, tables, engine) stops the grant counting.
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.db_roles ADD COLUMN IF NOT EXISTS jit_request_id uuid;
ALTER TABLE did.db_roles ADD COLUMN IF NOT EXISTS owner_email    text;
ALTER TABLE did.db_roles ADD COLUMN IF NOT EXISTS policy_id      uuid;

-- One account per request per server, whatever its name.
CREATE UNIQUE INDEX IF NOT EXISTS db_roles_jit_request
    ON did.db_roles (org_id, db_host_id, jit_request_id) WHERE jit_request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS db_roles_jit_role
    ON did.db_roles (org_id, role) WHERE jit_request_id IS NOT NULL;

ALTER TABLE did.db_access_requests ADD COLUMN IF NOT EXISTS policy_fingerprint text;
