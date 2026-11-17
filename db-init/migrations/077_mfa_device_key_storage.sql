-- 077: where a device keeps its signing key, as the app reports it at enrollment.
--
-- 'hardware' (Secure Enclave, Android Keystore, TPM / Windows Hello) or 'software' (a key in a
-- file, which is what the Linux desktop app will have). Shown in the admin device list so an
-- admin can tell the two apart. Empty for a device enrolled before the app sent it: every phone
-- so far, all of them hardware-backed.
--
-- Lives in each org's database. Replayed on every start: IF NOT EXISTS.

ALTER TABLE did.mfa_devices
    ADD COLUMN IF NOT EXISTS key_storage text NOT NULL DEFAULT '';
