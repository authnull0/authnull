-- 091: the conditional access decision log -- every policy decision the engine makes, on every
-- product, with each policy's own result (Entra's sign-in log, Conditional Access tab).
--
-- Written by authnull-service at decision time (internal/policy/decisionlog), one row per
-- question: before the push, and again after it when there was one (phase). evaluations is the
-- list of policies that name the person, enforced and report-only, with what each did
-- (dto.PolicyEvaluation). Append-only; read by administrators (/policyService/decisionLog/list).
--
-- Lives in each org's database. Replayed on every start: idempotent.

CREATE TABLE IF NOT EXISTS did.ca_decision_log (
    id               uuid PRIMARY KEY,
    org_id           integer NOT NULL,
    tenant_id        integer NOT NULL DEFAULT 0,
    channel          text NOT NULL,             -- DATABASE, SSH, AD, RADIUS, APP
    phase            text NOT NULL,             -- before_push, after_push
    subject          text NOT NULL DEFAULT '',  -- email or account
    resource         text NOT NULL DEFAULT '',  -- what was reached, per channel
    source_ip        text NOT NULL DEFAULT '',
    country          text NOT NULL DEFAULT '',
    risk_level       text NOT NULL DEFAULT '',
    decision         text NOT NULL,             -- allow, mfa_required, block, none (no policy)
    condition_denied boolean NOT NULL DEFAULT false,
    policy_id        text NOT NULL DEFAULT '',
    policy_name      text NOT NULL DEFAULT '',
    reason           text NOT NULL DEFAULT '',
    evaluations      jsonb NOT NULL DEFAULT '[]',
    created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ca_decision_log_org_time ON did.ca_decision_log (org_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ca_decision_log_subject ON did.ca_decision_log (org_id, lower(subject), created_at DESC);
