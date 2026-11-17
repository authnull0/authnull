-- 068: client credentials for database proxies (ProxySQL), DB-MFA-HARDENING S3.
--
-- Lives in each org's database and follows 049_ad_sensor_credentials: a client id and secret are
-- issued when an admin downloads db.env for a proxy install, the secret is stored only as a
-- SHA-256 hash, and the proxy trades the pair for a short-lived bearer token at
-- /api/v1/database/proxy/token. authn-service checks that token on every do-authenticationV4 call
-- the proxy makes (AUTH-212 caller "db-proxy"), so only a proxy of this org and tenant can ask for
-- database login decisions.
--
-- An org may hold several live credentials, one per proxy install. A credential stops working
-- when revoked_at is set.
--
-- Replayed on every start: everything here is IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS did.db_proxy_credentials (
    id            serial PRIMARY KEY,
    org_id        integer     NOT NULL,
    tenant_id     integer     NOT NULL,
    label         text        NOT NULL DEFAULT '',
    client_id     text        NOT NULL UNIQUE,
    secret_hash   text        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    created_by    integer,
    last_used_at  timestamptz,
    revoked_at    timestamptz
);

CREATE INDEX IF NOT EXISTS db_proxy_credentials_org
    ON did.db_proxy_credentials (org_id) WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS did.db_proxy_tokens (
    token_hash     text        PRIMARY KEY,
    credential_id  integer     NOT NULL REFERENCES did.db_proxy_credentials (id),
    org_id         integer     NOT NULL,
    tenant_id      integer     NOT NULL,
    issued_at      timestamptz NOT NULL DEFAULT now(),
    expires_at     timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS db_proxy_tokens_expiry ON did.db_proxy_tokens (expires_at);
