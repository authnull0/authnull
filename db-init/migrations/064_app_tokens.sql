-- Access tokens of MFA API applications, readable by authn-service.
--
-- An MFA API application (did.idp_apps, protocol 'mfa_api') exchanges its
-- client id and secret (did.app_clients) at <issuer>/oauth2/token -- the client
-- credentials grant -- for a short-lived token "apt.<org>.<random>". The app
-- presents it as "Authorization: Bearer" to authn-service's
-- do-authenticationV4 (credentialType APP), and to AuthNull's own MFA API.
--
-- Only the token's SHA-256 is stored, as for gateway (gwt.) and AD sensor
-- (snt.) tokens: the org in the token says which database to look in, and
-- authn-service, which already reads the org databases, checks it there. A
-- token stops working when it expires, when the app is disabled or deleted,
-- or when its secret is rotated (the rows are deleted).
--
-- Numbered 064, following 063_app_client_secret_hint.sql. Safe to run repeatedly.

CREATE TABLE IF NOT EXISTS did.app_tokens (
    token_hash text        PRIMARY KEY,
    app_id     uuid        NOT NULL REFERENCES did.idp_apps (id) ON DELETE CASCADE,
    org_id     integer     NOT NULL,
    tenant_id  integer     NOT NULL,
    client_id  text        NOT NULL,
    issued_at  timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS app_tokens_app ON did.app_tokens (app_id);
CREATE INDEX IF NOT EXISTS app_tokens_expiry ON did.app_tokens (expires_at);
