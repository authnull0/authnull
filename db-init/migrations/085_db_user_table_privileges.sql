-- 085: what a database user can do on each table (the console's User Privileges page).
--
-- Discovery reported only database-level privileges, and for PostgreSQL only one of them, so every
-- user read "CONNECT". The agent now sends each user's table privileges as well:
-- [{"table": "public.orders", "privileges": ["INSERT", "SELECT"]}], kept here per user and database
-- (a db_user row is one user on one database). repo/user_privileges.go.
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.db_user ADD COLUMN IF NOT EXISTS table_privileges jsonb;
