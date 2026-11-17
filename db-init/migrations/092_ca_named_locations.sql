-- 092: named locations for conditional access (Entra's): a name, IP ranges and/or countries, and
-- whether the location is trusted. Policies reference them by id in conditions.location
-- (internal/policy/conditions/location.go); managed at /policyService/namedLocations/*.
--
-- Lives in each org's database. Replayed on every start: idempotent.

CREATE TABLE IF NOT EXISTS did.ca_named_locations (
    id         uuid PRIMARY KEY,
    org_id     integer NOT NULL,
    tenant_id  integer NOT NULL DEFAULT 0,
    name       text NOT NULL,
    ip_ranges  jsonb NOT NULL DEFAULT '[]',
    countries  jsonb NOT NULL DEFAULT '[]',
    trusted    boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by integer
);
CREATE UNIQUE INDEX IF NOT EXISTS ca_named_locations_name ON did.ca_named_locations (org_id, tenant_id, lower(name));
