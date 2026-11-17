-- Mark the "deny anything not covered" policies as fallbacks.
--
-- The policy engine now applies one rule on every channel: a MATCHING BLOCK GOVERNS,
-- whatever else matches (internal/policy/engine, docs/POLICY-ENGINE.md). Before it, AD and
-- RADIUS let the first match in order govern, and "deny anything my policies do not cover"
-- was written as a block policy that sorted LAST -- a matchAll block (scripts/
-- ad-whitelist-restore.sql, shape A) or a block sibling behind each policy (shape B).
--
-- Under the new rule those blocks would govern every login they match, which is every login.
-- So a policy is now marked "fallback": true to mean "consider me only when no other policy
-- governs", and this migration marks the ones the restore script created, which are named
-- "Deny uncovered contexts -- <domain>" and "Deny uncovered -- <policy>". Their behaviour is
-- unchanged by the upgrade.
--
-- Hand-written matchAll blocks are NOT touched: nothing distinguishes one meant as a fallback
-- from one meant as a freeze, and guessing either way changes who can sign in. Review them
-- with the query in docs/POLICY-ENGINE.md ("Upgrading") before or after upgrading.
--
-- Numbered 066, following 065_app_mfa_settings.sql. Safe to run repeatedly, and a no-op on a
-- database without the table.

DO $$
BEGIN
  IF to_regclass('did.auth_policy_json') IS NOT NULL THEN
    UPDATE did.auth_policy_json
       SET policy_json = policy_json || '{"fallback": true}'::jsonb
     WHERE (policy_name LIKE 'Deny uncovered contexts -- %' OR policy_name LIKE 'Deny uncovered -- %')
       AND lower(trim(coalesce(policy_json->>'policyFlow', ''))) IN ('block', 'deny')
       AND coalesce(policy_json->>'fallback', 'false') <> 'true';
  END IF;
END $$;
