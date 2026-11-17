-- 084: a database server is identified by its port too (MySQL support).
--
-- db_hosts was unique on (org, tenant, agent VM, host VM), and every new host was stored with
-- port 5432. So a MySQL server and a PostgreSQL server on the same VM behind the same agent shared
-- one row, and a MySQL host was stored with the wrong port -- which the agent's "ip:port" lookups
-- (dbvault hostIDs) then never matched. Hosts are now (org, tenant, agent VM, host VM, port); a
-- MySQL row still holding the 5432 default gets MySQL's 3306.
--
-- Lives in each org's database. Replayed on every start: idempotent.

UPDATE did.db_hosts SET port = 3306
 WHERE lower(coalesce(db_type, '')) IN ('mysql', 'mariadb') AND port = 5432;

ALTER TABLE did.db_hosts DROP CONSTRAINT IF EXISTS db_hosts_org_id_tenant_id_agent_vm_ip_host_vm_ip_key;
CREATE UNIQUE INDEX IF NOT EXISTS db_hosts_identity
    ON did.db_hosts (org_id, tenant_id, agent_vm_ip, host_vm_ip, port) WHERE status IS DISTINCT FROM 'DELETED';
