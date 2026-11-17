-- 069: the database agent's verdict on direct access to the database server (DB-MFA-HARDENING S1).
--
-- MFA happens at ProxySQL; a client that can reach Postgres directly as a managed role skips it.
-- Every sync the agent reads the server's pg_hba rules and reports whether anything but the proxy
-- can log in as a managed role ("protected", "exposed" or "unknown", with the rules that say so
-- and the lines to add). It arrives with the agent's last-active report and is stored on its
-- did.epm_machines row, for the console's database-agent page.
--
-- Replayed on every start: idempotent, and a database without epm_machines is left alone.

DO $$
BEGIN
    IF to_regclass('did.epm_machines') IS NOT NULL THEN
        ALTER TABLE did.epm_machines ADD COLUMN IF NOT EXISTS direct_access_status     text;
        ALTER TABLE did.epm_machines ADD COLUMN IF NOT EXISTS direct_access_detail     text;
        ALTER TABLE did.epm_machines ADD COLUMN IF NOT EXISTS direct_access_checked_at timestamptz;
    END IF;
END
$$;
