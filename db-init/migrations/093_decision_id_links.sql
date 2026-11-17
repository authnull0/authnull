-- 093: link each product's log row to its conditional access decision.
--
-- authn-service stores the engine's decisionId (did.ca_decision_log.id, the answer before any
-- push) on the rows it writes: did.db_access_log (database logins) and did.auth_log (SSH, RADIUS,
-- app and the database summary rows). The answer after the push points back to it in
-- related_decision_id, so a sign-in's two steps are found together
-- (/policyService/decisionLog/list {"decisionId"}).
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.db_access_log   ADD COLUMN IF NOT EXISTS decision_id text;
ALTER TABLE did.auth_log        ADD COLUMN IF NOT EXISTS decision_id text;
ALTER TABLE did.ca_decision_log ADD COLUMN IF NOT EXISTS related_decision_id text;
CREATE INDEX IF NOT EXISTS ca_decision_log_related ON did.ca_decision_log (related_decision_id) WHERE related_decision_id IS NOT NULL;
