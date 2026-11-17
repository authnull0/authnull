-- 087: retire databases discovery no longer finds.
--
-- As with users (083): each sync of a database stamps last_seen, and a database nobody has reported is
-- marked DELETED -- which takes it, and its users, off the console (every list joins on a database
-- that is not DELETED):
--   - after 15 minutes, when its host's other databases are still being reported (dropped, or no
--     longer synced -- the agent's integration-test databases on the lab);
--   - after 30 days in any case (a server no agent serves any more), so a host that is down for a few
--     days keeps its data. repo/db_seen.go.
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.db_synchronization ADD COLUMN IF NOT EXISTS last_seen timestamptz;
-- Set when retirement (not an administrator) marked it DELETED: a retired database reported again
-- comes back; one an administrator deleted stays deleted.
ALTER TABLE did.db_synchronization ADD COLUMN IF NOT EXISTS retired_at timestamptz;
-- Databases from before 087 start the clock now.
UPDATE did.db_synchronization SET last_seen = now() WHERE last_seen IS NULL AND status IS DISTINCT FROM 'DELETED';
CREATE INDEX IF NOT EXISTS db_sync_host_seen ON did.db_synchronization (host_id, last_seen) WHERE status IS DISTINCT FROM 'DELETED';
