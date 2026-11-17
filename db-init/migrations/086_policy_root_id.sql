-- 086: a policy keeps one identity across its versions.
--
-- Saving a policy inserts a new row with a new id (parent_id: the version it replaces) and marks the
-- old row history. Everything that kept a policy id -- access requests and grants, the connection
-- page's access state, session and recording filters -- stopped matching the policy after an edit:
-- a JIT grant on v1 did not let a login through under v2, an approver could not decide a request made
-- before the edit, and a second request was allowed while one was pending.
--
-- root_id is the policy's first version, the same on every version. A trigger fills it on every
-- insert, whatever saves the policy: the root of the row it replaces, or its own id.
--
-- Lives in each org's database. Replayed on every start: idempotent.

ALTER TABLE did.auth_policy_json ADD COLUMN IF NOT EXISTS root_id uuid;

-- Existing rows: follow parent_id back to the version that is its own parent (or has none).
WITH RECURSIVE chain (id, root) AS (
    SELECT id, id FROM did.auth_policy_json WHERE parent_id IS NULL OR parent_id = id
    UNION ALL
    SELECT p.id, chain.root FROM did.auth_policy_json p JOIN chain ON p.parent_id = chain.id AND p.id <> chain.id
)
UPDATE did.auth_policy_json a SET root_id = chain.root FROM chain WHERE a.id = chain.id AND a.root_id IS NULL;
UPDATE did.auth_policy_json SET root_id = id WHERE root_id IS NULL; -- a parent that no longer exists

CREATE OR REPLACE FUNCTION did.auth_policy_json_root() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.root_id IS NULL THEN
        IF NEW.parent_id IS NOT NULL AND NEW.parent_id <> NEW.id THEN
            SELECT coalesce(root_id, id) INTO NEW.root_id FROM did.auth_policy_json WHERE id = NEW.parent_id;
        END IF;
        NEW.root_id := coalesce(NEW.root_id, NEW.id);
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS auth_policy_json_root ON did.auth_policy_json;
CREATE TRIGGER auth_policy_json_root BEFORE INSERT ON did.auth_policy_json
    FOR EACH ROW EXECUTE FUNCTION did.auth_policy_json_root();

CREATE INDEX IF NOT EXISTS auth_policy_json_root_idx ON did.auth_policy_json (root_id);
