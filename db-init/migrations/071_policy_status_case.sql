-- 071: policy statuses in the spelling every reader filters on.
--
-- PolicyAction stored the status as the caller sent it, so a policy approved with "approved"
-- (which docs/POLICY-API.md documented) was saved lowercase. Everything that reads policies
-- filters on "Approved", so such a policy matched nothing -- no connection strings, no policy
-- search -- while the console listed it as approved. PolicyAction now stores the canonical
-- spelling; this fixes rows written before.
--
-- Replayed on every start: idempotent, and a no-op on a database without the table.

DO $$
BEGIN
  IF to_regclass('did.auth_policy_json') IS NOT NULL THEN
    UPDATE did.auth_policy_json SET status = 'Approved'  WHERE lower(trim(status)) = 'approved'  AND status <> 'Approved';
    UPDATE did.auth_policy_json SET status = 'Suspended' WHERE lower(trim(status)) = 'suspended' AND status <> 'Suspended';
    UPDATE did.auth_policy_json SET status = 'Deleted'   WHERE lower(trim(status)) = 'deleted'   AND status <> 'Deleted';
  END IF;
END $$;
