-- The public keys Core checks pushed content's signatures with, by key ID (PUSH-R11, PUSH-R12): the backend's current
-- key and its next one, so it can switch to the next whenever it likes. Keys rotate through releases: release N ships
-- A (current) and B (next), the backend starts signing with B, and release N+1 ships B and C and drops A. A leaked key
-- is dropped in the next release; until players update, a file's `expires` and the last accepted `seq` bound it.
--
-- To add a key, given its public PEM from pagle-backend:
--
--     scripts/pushed-key.py <key.pem> <keyId>
--
-- prints the entry to paste below: n, the 2048-bit modulus, and rr (R^2 mod n) and n0inv (-n^-1 mod 2^24), the two
-- values logic/Rsa.lua's Montgomery multiplication needs, worked out once there so a login does no key setup. The
-- exponent is always 65537, so it isn't stored. A file whose keyId isn't here is absent (PUSH-R13).
--
-- The table ships empty: pagle-backend #2 hasn't published its keys, and the first ones come with the backend. Until
-- then every pushed file is absent, which is harmless at 1.0: the companion hint is off (HNT-R172) and Hunts' fallback
-- rotation runs whenever the file is absent.

---@class PagleNS
local ns = select(2, ...)

---@class PaglePushedKey
---@field n string the modulus, 512 lowercase hex digits, big-endian
---@field rr string R^2 mod n, with R = 2^(24 * 86), in the same form
---@field n0inv integer -n^-1 mod 2^24

---@type table<string, PaglePushedKey>
ns.PUSHED_KEYS = {}
