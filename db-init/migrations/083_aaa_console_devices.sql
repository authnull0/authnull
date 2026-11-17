-- AuthNull AAA: devices from the console (phase 1).
--
-- An admin adds a network device in the console and the AuthNull AAA server (authnull-aaa) it
-- sends logins to pulls it (POST /api/v1/aaa/config), with no edit of aaa.yml.
--
--   radius_servers.token_hash  hex SHA-256 of the server token, which goes into the AAA server's
--                              app.env as SERVER_TOKEN and is shown only once. Only the config pull
--                              needs it. NULL: the server gets no devices from the console (servers
--                              registered before this).
--   aaa_device_settings        what the AAA server needs for one device: which protocols it uses
--                              and the vault secret that holds its RADIUS secret and TACACS+ key.
--                              Goes with its device (ON DELETE CASCADE).
--
-- The secret is a vault secret (kind radius_device_secret, organisation level, account
-- radius-device:<device id>), plaintext JSON {"radiusSecret": "...", "tacacsKey": "..."}.
-- vault_secrets_kind_check is owned by 042_admin_account.sql; the new kind is added there.
--
-- Numbered 083, following 082_db_session_recordings.sql. Safe to replay: IF NOT EXISTS.

ALTER TABLE did.radius_servers ADD COLUMN IF NOT EXISTS token_hash text NULL;

CREATE TABLE IF NOT EXISTS did.aaa_device_settings (
    device_id                      uuid        PRIMARY KEY REFERENCES did.network_devices(id) ON DELETE CASCADE,
    org_id                         integer     NOT NULL,
    tenant_id                      integer     NOT NULL,
    radius                         boolean     NOT NULL,
    tacacs                         boolean     NOT NULL,
    allow_no_message_authenticator boolean     NOT NULL DEFAULT true,
    vault_secret_id                uuid        NOT NULL,
    updated_at                     timestamptz NOT NULL DEFAULT now()
);
