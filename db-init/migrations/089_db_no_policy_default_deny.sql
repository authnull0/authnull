-- 089: a database login no policy covers is refused unless the tenant chose otherwise (DBPAM-05).
--
-- no_policy_action (070) defaulted to 'allow', and the rotation setting (073) shares the row: a
-- tenant that only set the rotation interval got a row reading 'allow' without ever choosing it.
-- no_policy_action_set records a choice made in the console (nopolicy.Set). A row without one
-- reads as the default, which is now deny.
--
-- Rows written before this migration: 'mfa' and 'deny' were surely chosen and count as set;
-- 'allow' cannot be told from the old default and does not (an administrator who wants it chooses
-- it again). That runs once, when the column is added; replays leave later choices alone.
--
-- Lives in each org's database. Replayed on every start: idempotent.

DO $$
BEGIN
    IF to_regclass('did.database_access_settings') IS NULL THEN
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'did'
                   AND table_name = 'database_access_settings' AND column_name = 'no_policy_action_set') THEN
        ALTER TABLE did.database_access_settings ADD COLUMN no_policy_action_set boolean NOT NULL DEFAULT false;
        UPDATE did.database_access_settings SET no_policy_action_set = true WHERE no_policy_action IN ('mfa', 'deny');
    END IF;
    ALTER TABLE did.database_access_settings ALTER COLUMN no_policy_action SET DEFAULT 'deny';
END $$;
