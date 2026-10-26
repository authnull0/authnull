# AuthNull On-Prem

Deployment bundle for running the AuthNull identity platform (MFA, PAM, AD/Entra/Okta
integration, SSO, policy engine, credential vault) on a single Linux VM with Docker Compose,
fronted by host-level nginx.

This repository contains **deployment artifacts only** — no application source. All service
images are pulled from `docker-repo-public.authnull.com`.

```
.
├── docker-compose.yml        # full stack definition
├── .env                      # environment for docker compose (see Configuration)
├── db-init/
│   ├── 01_schema.sql         # master "did" schema (pg_dump, Postgres 16)
│   └── migrations/NNN_*.sql  # idempotent migrations, replayed on every `up`
└── nginx/
    ├── nginx.conf            # domain + HTTPS mode (Let's Encrypt)
    └── nginx-ip.conf         # bare-IP, plain-HTTP mode
```

## Services

| Service | Image | Host port | Purpose |
|---|---|---|---|
| `postgres` | `postgres:16-alpine` | 5432 | Master DB plus one database per organisation |
| `did-schema-init` | `postgres:16-alpine` | — | One-shot: applies schema + migrations, then exits |
| `redis` | `redis:7-alpine` | 6379 | Sessions / cache (password protected, AOF on) |
| `authnull-service` | `authnull-service:1.0.0` | 8080 | Consolidated backend: ad, dashboard, database, dbconsole, entra, issuer, mfa, okta, pam, policy, user, verifier, wallet |
| `authnz` | `authnz:1.0.0` | 6066 | Token validation sidecar |
| `authn-service` | `authn-service:2.0.0` | 2882 | Authentication engine (base path `/authnull0`) |
| `did-react` | `authnull-admin-ui:2.0.0` | 5173 → 3000 | Admin console (React) |
| `self-service-console` | `self-service:onprem` | 3000 | End-user self-service portal |
| `secret-management-service` | `secret-management-service:1.0.0` | 9291 | Credential retrieval |
| `log-service` | `log-service:1.0.0` | 9255 | Audit / access logs |
| `cassandra` | `cassandra:3.11` | 9042 | Temporal keyspace storage |
| `cassandra-init` | `cassandra:3.11` | — | One-shot: creates the `temporal` keyspace |

All containers join the `authnull` bridge network (`10.250.0.0/24`). Start order is enforced
with health checks: `postgres` + `redis` healthy → `did-schema-init` completes →
`authnull-service` healthy (`/system/v1/health`) → `did-react`.

Container names follow `COMPOSE_PROJECT_NAME` from `.env` (`onprem-<service>-1`), not the
`name: authnull` in the compose file.

## Prerequisites

- Linux VM with Docker Engine and the Docker Compose v2 plugin
- nginx installed on the host (it proxies to `127.0.0.1:<port>`)
- For domain mode: DNS A records for the main and tenant hostnames, ports 80/443 open, and `certbot`
- Network access to `docker-repo-public.authnull.com`

## Configuration

Compose reads `.env` from this directory. Production can use a separate file:
`docker compose --env-file .env.prod up -d` (`.env.prod` is gitignored).

### Values the customer must fill in

The committed `.env` is a template with no secrets in it. Every value the customer has to
supply is marked `# [REQUIRED]`. List them with:

```bash
grep -n -A1 '\[REQUIRED\]' .env
```

| Variable(s) | What to put |
|---|---|
| `DB_USER` / `POSTGRES_USER` | Any username for the bundled Postgres. Both must be identical |
| `DB_PASSWORD` / `POSTGRES_PASSWORD` | Any strong password. Both must be identical |
| `ORG_NAME` | The org's short name, e.g. `acme`. It's used in `default.<org>.<domain>` |
| URL block A **or** B | Uncomment one: **A** for domain + HTTPS, **B** for bare IP. Sets `SYSTEM_URL`, `DOMAIN_URL`, `TENANT_BASE_DOMAIN`, `SSC_*`, `CLIENT_URL`, `ROOT_URL`, `AUTHNULL_LOGOUT_URL`, `WEBAUTHN_*` |
| `JWT_SECRET`, `INTERNAL_API_KEY`, `REDIS_PASSWORD` | `openssl rand -hex 32` |
| `TOTP_ENCRYPTION_KEY` | `openssl rand -hex 32` (64 hex chars) |
| `ENCRYPTION_KEY` | `openssl rand -hex 16` (exactly 32 hex chars) |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_FROM`, `SMTP_PASSWORD` | The customer's mail relay, used for verification and invite emails |

Never change `ENCRYPTION_KEY` or `TOTP_ENCRYPTION_KEY` after the first start. A changed key
doesn't fail loudly: stored data silently becomes unreadable and users are locked out of MFA.
Back up the filled-in `.env`, and don't commit it.

Optional integrations (Twilio, Duo, Okta, Azure/AWS storage, push-MFA tuning) are further down
in `.env`. Leave them blank to disable them. For SMS, set `TWILIO_FROM_NUMBER`: the service
doesn't read `TWILIO_PHONE`.

### Push MFA (Firebase)

When an org's `MFA_PROVIDER` is `authnull`, push notifications go through FCM. Put the service
account file at:

```
secrets/fcm-service-account.json
```

It is mounted read-only at `/run/secrets/fcm-service-account.json`, so set
`FCM_SERVICE_ACCOUNT_JSON` to that path. `secrets/` is gitignored. If the file is missing, Docker
creates an empty **directory** with that name and push silently stops working. Check it with
`ls -la secrets/`.

### Notable tuning knobs

- `DB_MAX_OPEN_CONNS` / `DB_MAX_IDLE_CONNS`: these are **per database**. The ceiling is
  `(orgs + 1) × DB_MAX_OPEN_CONNS` and has to fit inside Postgres `max_connections`.
- `MFA_PUSH_SWEEP_ENABLED=true`: set it on exactly one replica (there is no leader election).
- `MFA_PUSH_ALLOW_UNSIGNED`: empty or unparseable means signatures are **enforced**.
- `MFA_PUSH_RISK_ENABLED`: leave it `false` until about a week of activity has accumulated.
- `ORG_DISCOVERY_ENABLED`: an email-to-org lookup that is off by default because it allows account enumeration.
- `TRUSTED_PROXIES`: set this to the nginx address(es), or client IPs will show as the proxy.

## Running

```bash
docker compose pull
docker compose up -d
docker compose ps
```

`authnull-service` has a `build:` section pointing at a `Dockerfile` that is not in this repo,
so **don't use `--build`**. Pull the published image instead.

Common operations:

```bash
docker compose logs -f authnull-service
docker compose logs did-schema-init
docker compose pull authnull-service && docker compose up -d authnull-service
docker compose down
```

`docker compose down -v` also deletes all data volumes (Postgres, Redis, recordings, uploads).

## Database

- `postgres` runs `db-init/` as `/docker-entrypoint-initdb.d`, but only on a first boot with an
  empty volume.
- On **every** `up`, `did-schema-init`:
  1. waits for Postgres to accept TCP logins,
  2. applies `01_schema.sql` to the master DB (`DB_NAME`) if `did.organizations` is missing,
  3. replays every `migrations/*.sql` against the master **and every database that has a `did`
     schema**, which means every org database too.
- If a migration fails, `did-schema-init` exits non-zero and `authnull-service` won't start.
- Per-org databases are **not** created here. `authnull-service` provisions them (pg_dump of the
  master, then `CREATE DATABASE <org>`) after an org is approved. Don't pre-create them, or
  provisioning fails and login returns "Tenant not found or inactive".

### Adding a migration

Add `db-init/migrations/NNN_description.sql` with the next number. There is no ledger table, so
every statement **must be idempotent** (`CREATE ... IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`,
guarded `DO $$ ... $$` blocks). The file is replayed against every database on every `up`.

Volumes: Postgres data lives in `pgdata`. `postgres-data` and `postgres-bitnami-data` are older
volumes kept as backups and are not mounted.

## nginx

nginx runs on the host, not in compose. Pick one config:

### Domain + HTTPS (`nginx/nginx.conf`)

Serves the main site (`SYSTEM_URL` host) and the tenant site (`default.<org>.<domain>`).
Unknown hosts and bare-IP requests get no site.

```bash
sed -e 's/<org>/acme/g' -e 's/example\.com/mycorp.com/g' nginx/nginx.conf | sudo tee /etc/nginx/nginx.conf > /dev/null
```

```bash
sudo certbot certonly --nginx -d onprem.mycorp.com
```

```bash
sudo certbot certonly --nginx -d default.acme.mycorp.com
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Bare IP, HTTP (`nginx/nginx-ip.conf`)

Serves the admin UI and API at `http://<vm-ip>`. Tenant login still needs a hostname, because
the backend reads the org from the second label of `default.<org>.<domain>`. Map that name to the
VM (DNS or hosts file), set `DOMAIN_URL` / `TENANT_BASE_DOMAIN` to match, and uncomment the
tenant origin in the CORS map.

### Routing summary

| Path | Upstream |
|---|---|
| `/` | `did-react` (5173) |
| `/ssc/`, `/ssc-static/`, `/ssc-env.js` | `self-service-console` (3000) |
| `/authnull0/api/v1/authn/` | `authn-service` (2882) |
| `/authnz/` | `authnz` (6066) |
| `/api/v1/log/` | `log-service` (9255) |
| `/api/v1/secretservice/` | `secret-management-service` (9291) |
| `/console/` | `authnull-service` `/api/v1/dbconsole/` |
| `/okta/` | `authnull-service` `/authentication/okta/` |
| `/api/v1/`, `/pam/`, `/ad/`, `/authentication/` | `authnull-service` (8080) |

## Security notes

- The committed `.env` is a blank template. Never commit a filled-in copy. Keep real values in
  the deployed copy on the VM, or in `.env.prod` (gitignored).
- Every port is published on **all interfaces**, including 5432, 6379, 9042, 6066, 2882, 9255
  and 9291. Docker bypasses `ufw`, so these are reachable from the network even with a host
  firewall. With nginx in front, change the mappings to `"127.0.0.1:PORT:PORT"` so only 80/443
  are public.
- Never commit `secrets/` or any `*-service-account.json`. A Firebase key can't be scoped down.

## Known gaps

- `authn-service` has `KAFKA_BROKERS` hardcoded to an AuthNull-internal IP (`10.104.14.189`).
  The `KAFKA_*` values in `.env` are ignored.
- `RISK_API_INTERNAL` points at `aipolicyagent`, and `authnull-service` points at `ssi-service`.
  Neither service is defined in this compose file.
- The header comments in `docker-compose.yml` mention `--profile ssi/authn`, a Bitnami Postgres
  image and loopback-only ports. None of these match the current file: no profiles are defined,
  Postgres is `postgres:16-alpine`, and ports are bound publicly.
- `.env` has MinIO and AWS recording values, but no MinIO service or wiring exists here.
- Migration `012` is absent from the sequence. It is a numbering gap, not a missing step.
