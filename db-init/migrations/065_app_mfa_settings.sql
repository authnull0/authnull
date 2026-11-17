-- Per-application settings of an MFA API application's hosted second factor
-- (the redirect flow: /oauth2/par -> /oauth2/authorize -> AuthNull's approve
-- page -> code -> /oauth2/token).
--
--   session_ttl_seconds  how long the ID token the application gets lasts: the
--                        application's session after a second factor (8 hours)
--   mfa_methods          which second factors the application allows: "push",
--                        "totp" (both). authn-service enforces it in
--                        do-authenticationV4, for the redirect flow and for an
--                        application calling it with its own token.
--
-- Numbered 065, following 064_app_tokens.sql. Safe to run repeatedly.

ALTER TABLE did.idp_apps ADD COLUMN IF NOT EXISTS session_ttl_seconds integer NOT NULL DEFAULT 28800;
ALTER TABLE did.idp_apps ADD COLUMN IF NOT EXISTS mfa_methods jsonb NOT NULL DEFAULT '["push","totp"]'::jsonb;
