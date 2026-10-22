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
-- The keys shipped, from pagle-backend's ops/content-keys/ at its commit ede15a8, each RSA-2048 with e = 65537:
-- - pagle-2026a, the current key, which the backend signs with;
-- - pagle-2026b, the next key.
-- The specs' TEST ONLY key is never here: a spec hands it to the reader itself (spec/Pagle/logic/PushedContent_spec.lua).

---@class PagleNS
local ns = select(2, ...)

---@class PaglePushedKey
---@field n string the modulus, 512 lowercase hex digits, big-endian
---@field rr string R^2 mod n, with R = 2^(24 * 86), in the same form
---@field n0inv integer -n^-1 mod 2^24

---@type table<string, PaglePushedKey>
ns.PUSHED_KEYS = {
	-- The current key.
	["pagle-2026a"] = {
		n = "b1abfa19eefdca20dcc7aaf0fc63150f1b36da5b5da27704c6164f70ebbb2303f3bd83efb1218ee3174593643db41a8f5ac4c92cd11713142e2a4b7096c573b5667bca887dd282fcfa684d69d888d4d68038cc06464620c86b730b739b2ede91afb6e83cb8116614af81abaabd0fabaa25e4c7d8d62dbd896d56fc3be3377987c93d019ebe6a62b04dd986f48e53b7100dd442b2fbbb0a1c07adfefd26bf2014e2ea87379510b59bd6ee02963f35dd382ce4a1459c582b37c4d5b269eb8f62c8cc0e76b78ba995c5a48746e1453c312717d13b5e718d9f7702ca4f2168a9220df835ef07b4351780c0806b1b751d93919ffebb5861136f9922ecfe8c7a6e7921",
		rr = "3c68289f7dbd4b313c3ba44f7b07b736c78f0361d5b94ddb5b1630945c1766b85dceccf7f825898bee7435516534ccc6bdf9fce28f943087fa28d7a1d89c2a0eb1e7931d3cd45c650dbbf3cbc6f3a6f99b4d28cbaeb4afc3526a3b58d026f840cdb80f858f147f4f56f0bd1bcbe2878516e2acfeb606e5a6f37c8bd970b12c56bb4618cc1f68a7bf59736a91d563b2f3645123a57caf59d4546c019ccb1cb616e585b837f28dd178786be0e22ac2b4ae467989e26e9f66ebc92bfe3f662ba95d8ccb2b1740e0d6a2da193e33805303476246126d6146309ded3877fe5405c8b3a18ab67b485d74975459070e6b997f57621e719e8e92903623c2ce2a5f182182",
		n0inv = 10204447,
	},
	-- The next key.
	["pagle-2026b"] = {
		n = "c84014d1a51eaefcfb47b5dfa2c13345897d5cefa491928cfd9242a043a1300d0643e444bd01be1ea2af3aa6e67003bb37bfd5016e1d2e75aa8df7f830645e56a53bc0da5cd31f7fe916848055598800d7a385057edf011d82db28c5ab9b34897479171d4ffd4b066872c9129ee77af500cb010cbc7e6bcd21be7dda09f9b89e6e1c3f1c54c734fd54eaa59e8d14e177854d6e83d5e01ddc2806281f7183c05a83dc335b8046c5bb0d07c0d758ac0776c951284911385484bf78ef61d3756e90684cc5bd07b2868f286ce04a2c568323e9eb070e571468723f5f70aaeb2eb1a41dd02b237ebd041c93227e2cf6dfb8aad42660a2aa20ea6ddfc05901710e4e73",
		rr = "746b2aadb057b3f4802498d94e8f10dc25e5b3c1d498bc0f321180e497aa531a6093b8164dd65381ee3533488c97752e72b2de40926a0e859c8a26c6e12d7b194c9ede155c625eb785f390bf2268d5e2b1fba5cf2c7e5acebb3df90f8904b0f4d13a9a045e8dc6eacd235e42ec914f105e727dff04e54e3e598e38e484f24e9a3343d00b0a3f1bb321a72eff521e3b91cf6d0754e90d4341d0a36b72952cc40e0ac9dd52a248d18ce04e14b1745fefe198c112c273e982b5ed744dc8b4a34415adf9aa934afb7bf9352ff61c164f1937595e6d8583851135b7348ab7342a0187f46206f96ddfc42c62c532fc840ae9e8b026b122bea441f692e192bd0ee654e2",
		n0inv = 915781,
	},
}
