-- 072: how much each synced database role can do, for policies' privilege condition
-- ("MFA for superuser roles only").
--
-- The database agent reports it with every role it syncs (privilegeLevel): admin (superuser, or
-- able to run programs or read and write files on the server), elevated (create roles or
-- databases, replication, bypass RLS, read or write all data) or standard. The policy engine's
-- database channel reads it for the role a login asks for. NULL until an agent that reports it
-- has synced: the privilege is then unknown, so Block and Require MFA policies with a privilege
-- condition still apply and Allow policies with one do not.
--
-- Replayed on every start: idempotent, and a no-op on a database without the table.

DO $$
BEGIN
  IF to_regclass('did.db_user') IS NOT NULL THEN
    ALTER TABLE did.db_user ADD COLUMN IF NOT EXISTS privilege_level text;
  END IF;
END $$;
