-- 073: how often the database agent rotates managed role passwords, per tenant (AUTH-233).
--
-- The agent rotates the passwords of the roles ProxySQL logs in as (database-agent S4). The
-- interval was PASSWORD_ROTATION_HOURS in each agent's db.env: set by whoever installed it,
-- invisible in the console, and different on every agent. It is now the tenant's choice in the
-- console (internal/database/rotation), sent to each agent in the response to its last-active
-- report.
--
-- A column on 070's table: both are a tenant's database access settings. Rows that exist
-- already (a tenant that chose a no-policy action) get the default, 24 hours -- the agent's own
-- default, so nothing changes until someone chooses. At most a year.
--
-- Lives in each org's database. Replayed on every start: IF NOT EXISTS.

ALTER TABLE did.database_access_settings
    ADD COLUMN IF NOT EXISTS password_rotation_hours integer NOT NULL DEFAULT 24
        CONSTRAINT database_access_settings_rotation_hours CHECK (password_rotation_hours BETWEEN 1 AND 8760);
