-- 090: where the phone was when it answered a push.
--
-- The respond endpoints now record the answering phone's address (X-Real-IP from the bundled
-- nginx). authn-service reads it with the verdict, looks up its country, and uses it for the
-- "approver must be in" policy action and as the person's last known location for logins that
-- arrive from an internal address. Requester columns (client_ip, geo_*) are unchanged.
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.mfa_push_activity ADD COLUMN IF NOT EXISTS responder_ip text;
ALTER TABLE did.ad_mfa_challenges ADD COLUMN IF NOT EXISTS responder_ip text;
