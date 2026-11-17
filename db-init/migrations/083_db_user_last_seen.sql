-- 083: retire database users discovery no longer finds.
--
-- The agent reports every user of every database it syncs, once a minute, one at a time; it never
-- says which users are gone. So each report now stamps last_seen, and a user nobody has reported
-- for a while is marked DELETED -- but only on a database whose sync is evidently running (another
-- user of it was seen recently), so an agent that is down retires nothing. A user that comes back
-- is discovered again as a new row. (internal/database/repo/user_seen.go)
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.db_user ADD COLUMN IF NOT EXISTS last_seen timestamptz;
CREATE INDEX IF NOT EXISTS db_user_db_seen ON did.db_user (db_id, last_seen) WHERE status IS DISTINCT FROM 'DELETED';
-- Users from before 083 start the clock now: one discovery no longer finds is retired 15 minutes
-- after this first runs. Only fills the gaps, so a replay changes nothing.
UPDATE did.db_user SET last_seen = now() WHERE last_seen IS NULL AND status IS DISTINCT FROM 'DELETED';
