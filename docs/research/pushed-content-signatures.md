# Checking signed pushed content in pure Lua inside the client

Research for issue #283, a child of map #277 (Hunt Events and pushed content). Researched 2026-10-18 against the Forever API dump of build 1.60.1.70338 (Ketho/BlizzardInterfaceResources `forever`, the commit `scripts/tools.env` pins) and stock PUC Lua 5.1.5.

**Question.** Can the addon check a signature on content the companion delivers, in pure Lua 5.1 inside the WoW client, at an acceptable cost? Which scheme, which code, how long it takes, who has done it before, and how the public key ships and rotates.

**Short answer.** Yes, and it is cheap.

1. **Recommended: RSA-2048, RSASSA-PKCS1-v1_5 with SHA-256 (Java's `SHA256withRSA`), public exponent 65537.** The check re-encodes the expected block and compares bytes; it never parses the decrypted block.
   - Measured in stock Lua 5.1.5: the modexp takes **4.7 ms** and SHA-256 over 4 KB takes **1–2 ms**, so about **6–7 ms per check** [M].
   - It needs about 150 lines of our own bignum code (24-bit limbs held in doubles, Montgomery multiplication) plus SHA-256. The bignum part uses **no `bit` calls at all**.
2. **Ed25519 is a close second on speed but costs more code.** The only pure-Lua implementation found that a Lua 5.1 port could start from is ccryptolib (MIT, written for ComputerCraft). Ported with a shim, it verifies in **4 ms plus SHA-512 of the message (3–10 ms over 4 KB)** [M].
   - The port means about 1,800 lines of unaudited third-party code.
   - It needs a `bit32` shim, fixes for `\x` escapes and an added `S < L` check.
3. **One check per login is far below any frame-time worry.** Even at 5× slower than the bench machine, a check is roughly 35 ms, once.
   - The client's "script ran too long" limit is undocumented. Run the check from a coroutine that yields between Montgomery multiplications (about 0.25 ms each), and it never matters.
4. **No WoW addon found verifies app-delivered data.** Raider.IO, TSM's AppHelper and WeakAuras' companion data are all trusted as written, and guarded only by staleness or user confirmation.
5. **Keys:** bake public keys into Core as a table keyed by key ID. Ship the next key one release ahead of its use. Retire a key by deleting it in a release. Bound the damage from a leaked key with a signed expiry and a monotonic sequence.
   - The private key lives only in the backend. The companion relays the signed bytes unchanged and holds no key.

Source trust levels used below:
- **[P]**: primary, meaning RFCs, JDK documentation, library and addon source code, the Blizzard API dump, and Warcraft Wiki API pages.
- **[M]**: measured for this note. Stock PUC Lua 5.1.5 with the luabitop rock, from `.tools/` (`scripts/tools.env`), under WSL on an Intel i7-13700K, timed with `os.clock()`. The harness is `pushed-content-signatures-bench.lua` next to this file.
- **[S]**: secondary, meaning a third-party reimplementation of another vendor's app.
- **[C]**: community forum reports, not independently verified.

---

## 1. What the client's Lua gives us

| Fact | Detail | Source |
|---|---|---|
| Language | "a modified version of Lua 5.1 that supports taint". The `os` and `io` libraries are absent. | Lua functions [P][1] |
| `bit` library | The Forever dump lists exactly `bit.arshift`, `band`, `bnot`, `bor`, `bxor`, `lshift`, `mod` and `rshift`. **No `tobit`, `tohex`, `rol`, `ror` or `bswap`.** The wiki calls it "the Lua bitlib library", available "since Patch 1.9". It "seems to work internally with standard 32-bit 'int' values". | API dump [P][2]; Lua functions [P][1] |
| `bit` result sign | Not documented: the wiki doesn't say whether results are signed or unsigned. Normalise every result with `% 2^32`, as LOG-R66 already does. | [P][1] |
| No `bit32`, no `ffi`, no `require` | None is in the dump. Loading is by TOC order (see `lua-toolchain.md`). | [P][2] |
| Present and useful | `loadstring`, `setfenv`, `coroutine.*` (create, resume, yield, wrap, status, running), `debugprofilestop`, `collectgarbage` | [P][2] |
| `C_EncodingUtil` | `EncodeBase64`/`DecodeBase64`, `EncodeHex`/`DecodeHex`, `SerializeJSON`/`DeserializeJSON`, `SerializeCBOR`/`DeserializeCBOR`, `CompressString`/`DecompressString`. **No hash, HMAC or signature function** anywhere in the dump. | [P][2] |
| No `\x` escapes | Lua 5.1 reads `"\x41"` as `"x41"`. Only `\ddd` decimal escapes exist. | Lua 5.1 manual §2.1 [P][3]; [M] |
| Long strings are not byte-safe | When `[==[` is followed by CR LF, that newline is dropped. **Every CR LF and every lone CR inside becomes LF.** `"[==[\r\na\r\nb\rc]==]"` loads as `61 0a 62 0a 63`. | [P][3] (first newline); [M] (CR handling) |
| "script ran too long" | **No documented limit, and no number.** Community reports say it was once combat-only, and has applied out of combat since 7.2.5, including at login with large load-on-demand addons. The usual cure is coroutines that yield, resumed from `OnUpdate` or `C_Timer`. | WoWInterface threads [C][4][5] |

**Two consequences beyond the signature question:**

- **The repo's specs call the client's `bit` "LuaBitOp"** (LOG-R66, `spec/support/client.lua`), and the fake client hands addons the full LuaBitOp. The dump says the real table has `bit.mod` and lacks `tobit`, `tohex`, `rol` and `ror`.
  - Today's code (FNV-1a and fmix32) uses only `bxor` and `rshift`, so nothing breaks.
  - But a crypto port that reached for `bit.ror` or `bit.tobit` would pass every spec and fail in the client. The fake client should expose only the eight names.
- **Signed bytes can't travel in a Lua long string.** The companion should write the payload as **Base64 or hex inside a quoted string**. The addon decodes it with `C_EncodingUtil.DecodeBase64` (or a pure-Lua decoder in `logic/`, so the backend's lua5.1 can run it too), verifies those bytes, and only then parses them.

---

## 2. The candidates and what they cost

The cost is for one check of one signature over a 4,096-byte payload in stock Lua 5.1.5 [M]. Correctness was checked against OpenSSL 3.5.6:
- OpenSSL made the keys and signed the same random 4 KB message with Ed25519 and with RSA `dgst -sha256 -sign` (PKCS#1 v1.5).
- Every Lua check accepted OpenSSL's signature and rejected the signature after one byte of the message or the signature was flipped.
- Ed25519 also passed RFC 8032 §7.1 TEST 1 [P][6].
- The SHA-256 output matched `openssl dgst -sha256`.

| Scheme | Lua code it needs | Signature step | Hash over 4 KB | **One check** | Key and signature size |
|---|---|---|---|---|---|
| **RSA-2048, e = 65537, PKCS#1 v1.5 + SHA-256** | About 150 lines of our own Montgomery modexp, plus SHA-256 | 4.7 ms (19 Montgomery multiplications at about 0.25 ms each) | SHA-256: 1.1 ms (sha2.lua, no `bit`) to 1.9 ms (through a Lua `bit` wrapper) | **≈ 6–7 ms** | 256 B modulus, 256 B signature |
| RSA-2048, e = 3 | Same | 1.0 ms | Same | ≈ 2–3 ms | Same |
| RSA-3072, e = 65537 | Same | 11.0 ms | Same | ≈ 12–13 ms | 384 B, 384 B |
| **Ed25519 (RFC 8032)** | ccryptolib port (about 1,800 lines) | 3.9 ms (point decode, two scalar multiplications, encode) | SHA-512: 1.7–2.8 ms (sha2.lua) or 10.2 ms (ccryptolib's own) | **≈ 6–14 ms** | 32 B key, 64 B signature |
| ECDSA P-256 | No pure-Lua 5.1 implementation found. We'd write the field, curve and inversion code ourselves. | Estimated about 1–1.5× Ed25519 (a double scalar multiplication over a 256-bit field plus one inversion mod n). Its reduction is shaped around 32-bit words, which suits 24-bit limbs badly. | SHA-256 | Not measured | 64 B key, about 72 B signature |
| Hash only (SHA-256 of the content, the expected value shipped in the addon) | SHA-256 | none | 1–2 ms | ≈ 1–2 ms | 32 B per item |

Notes on the numbers:

- **One-time key setup for RSA:** `R^2 mod n` takes 11 ms (2048) or 23 ms (3072) by repeated doubling. Precompute it and ship it next to the modulus, so it costs nothing at login.
- **The `bit` wrapper overstates the cost.** The harness built a WoW-shaped `bit` out of Lua functions that wrap LuaBitOp and add `% 2^32`, and sha2.lua's no-`bit` branch beat it. The client's real `bit` functions are C calls, so in-client hashing should land at or below the lower figure.
- **The WoW client is not stock Lua.** It adds taint tracking, and players' CPUs are slower than an i7-13700K. Allow a factor of 2–5: **RSA-2048 at about 15–35 ms and Ed25519 at about 15–70 ms, once per login.** The real figure should come from the probe (§7).
- Hashing costs about 0.3–0.5 ms per KB, so a 64 KB payload adds about 20–30 ms. To keep the signature step fixed whatever the size, sign a small manifest of per-item SHA-256 hashes (§5).

### Why RSA, when Ed25519 is about as fast

- **Less code, and code we own.** RSA verify is bignum multiplication and a byte comparison: about 150 lines, testable line by line against Wycheproof's RSA vectors [P][10]. Ed25519 means porting and keeping about 1,800 lines of field and curve arithmetic from a one-author, 33-star, unaudited library [P][7].
- **No `bit` dependency.** Montgomery multiplication on 24-bit limbs uses only `*`, `+` and `%` on doubles. Every product (less than 2^48) and every accumulator (less than 2^50) is exact below 2^53. That sidesteps the client's undocumented `bit` signedness and its missing rotates.
- **The verification rule is simple and standard.** RFC 8017 §8.2.2 builds the expected encoded message and compares it whole. Its Note says the alternative is to "apply a 'decoding' operation", which "requires additional code" [P][8].
  - Comparing the whole block is also what defeats Bleichenbacher's 2006 low-exponent forgery against lax parsers (background knowledge, not re-sourced here). With it, even e = 3 is safe. We still pick 65537, the default every toolkit emits, since 4.7 ms is affordable.
- **Every signer supports it natively.** The JDK's `SHA256withRSA` is "the RSA signature algorithm that uses the SHA-* digest with the RSASSA-PKCS1-v1_5 signature scheme as defined in PKCS #1 v2.2" [P][9].
- **Ed25519's advantages don't matter here.** Its key is 32 B against RSA's 256 B, and signing is faster, but neither counts for files on disk. The JDK has had `Ed25519` since JDK 15 (JEP 339) [P][9][11], so it stays a drop-in alternative if the backend prefers it.

---

## 3. Existing pure-Lua implementations

| Library | Licence | Lua target | What it has | Fit for WoW | Source |
|---|---|---|---|---|---|
| **pure_lua_SHA** (Egor Skriptunoff), `sha2.lua`, commit 6adac17 (2022-03-02) | MIT | 5.1–5.4, LuaJIT, Fengari. Has a "Lua 5.1 with external library `bit`" branch and a branch that needs no `bit` at all. | MD5, SHA-1, SHA-2 (224/256/384/512 and the truncated variants), SHA-3/SHAKE, HMAC, BLAKE2, BLAKE3 | **Use the no-`bit` branch or extract SHA-256.** With WoW's `bit` it asserts `"Library 'bit' is incomplete"`, because it needs `rol`/`ror`. It passes once rotates are added from shifts. The file is 276 KB, mostly other branches, so copy only the SHA-256 code we need. The README's speed table gives Lua 5.1 SHA-256 at 0.2 MB/s with no hardware stated; we measured about 3.6 MB/s on the no-`bit` branch. | [P][12] |
| **ccryptolib** (migeyel), commit 14489aa (2026-08-24) | MIT | CC:Tweaked (ComputerCraft): Lua 5.2 semantics, `bit32`, and `string.pack` when present (else it compiles packers with `load`) | Ed25519, X25519, SHA-256, SHA-512, ChaCha20, Poly1305, BLAKE3. Field arithmetic is in doubles with 24-bit limbs. | **Portable with a shim.** For the measurement here it needed: a `bit32` table built on `bit` (`lrotate`, `extract`, unsigned results); `table.unpack` mapped to `unpack`; `load(string)` mapped to `loadstring`; `"\x80"` rewritten to `"\128"`; and stubs for `cc.expect` and its hardware-accelerator module. **It doesn't reject `S ≥ L`**: `fq.decode` reduces S mod L, so it accepts malleable signatures, against RFC 8032 §5.1.7 [P][6]. That is harmless for authenticity, but a port should add the check. No audit, 33 stars. | [P][7] |
| **plc** (philanc) | MIT | **Lua 5.3+ only** ("bit operators and string pack/unpack are extensively used") | SHA-2, X25519, ChaCha20, Poly1305 and more. **No Ed25519** ("may come some day"). | Not usable as is. Its own timing, X25519 scalar multiplication at about 189 ms each in Lua 5.3.4 on an i5 M430, is a useful order-of-magnitude check. | [P][13] |
| **pure-lua-5.1-crypto** (BernhardZat) | see repo | Lua 5.1 | X25519, ChaCha20, Shamir. No signatures, no hash. | Not useful. | [14] |
| RSA in pure Lua 5.1 | — | — | No maintained library found. The common bignum libraries (for example lua-bint) need Lua 5.3 integers. | Write our own (§2). The Montgomery routine in the harness is a working prototype, not production code. | — |

**Licences.** Pagle is GPL-3.0-or-later (ADR 0006). MIT code may be combined into it, keeping its copyright notice. Code we write ourselves raises no question.

---

## 4. Prior art in WoW

No WoW addon found checks a signature or a hash on data an app delivered. Each one trusts the companion's file as written:

| Addon / app | What the app writes | What the addon checks | Source |
|---|---|---|---|
| **Raider.IO** (commit 9750036, 2026-10-18) | Regenerated `db/*.lua` data addons | **Only staleness.** `ns.OUTDATED_CUTOFF = 86400 * 3`: a warning after 3 days. `ns.OUTDATED_BLOCK_CUTOFF = 86400 * 7`: data hidden after 7 days. `core.lua` has no hash, checksum or signature. | [P][15] |
| **TSM Desktop App → TSM_AppHelper** | `AppData.lua` lines such as `select(2, ...).LoadData("TAG","Realm",[[return {...}]]) --<TAG,Realm,timestamp>` | Nothing beyond loading the string. A third-party Linux reimplementation writes the same file and TSM accepts it. That shows there is no signature, since that app holds no TSM key. | tsm-app-linux `lua_writer.py` and `docs/data.md` [S][16]; TSM support [P][17] |
| **WeakAuras + WeakAuras Companion** | A `WeakAurasCompanion` data addon (slugs, stash) | `WeakAuras.AddCompanionData` deep-merges it. Import strings (`!WA:2!` + LibDeflate + LibSerialize) carry **no signature**. Safety comes from the import dialog that the user confirms. | WeakAuras2 `WeakAuras.lua` and `Transmission.lua` (commit a690a22) [P][18] |
| Hash libraries for WoW | — | None found for WoW. LibHash (MD5, SHA-1, SHA-256) exists for WildStar. | [C][19] |

**What this means.** Pagle would be the first addon we know of to verify pushed content. Nothing in the ecosystem contradicts the approach, but there is no battle-tested WoW library to lean on. Raider.IO's age cutoffs carry over directly: an envelope with `expiresAt` is the signed version of the same idea.

---

## 5. What the signed envelope should be (input for the pushed-content contract)

These are requirements for the contract and for backend #2, not a finished design.

1. **The backend signs. The companion relays.** The private key never leaves the backend (keep it offline or in a KMS).
   - A key held by the companion would prove nothing: the companion runs on the player's machine, and anyone can read its key and sign with it.
   - The companion writes the backend's bytes and signature unchanged.
   - This answers the ticket's fallback "checking only the companion's own signature": it adds no security.
2. **Verify the exact bytes, then parse.** The data addon carries `{ v = 1, kid = "<key id>", payload = "<base64>", sig = "<base64 or hex>" }` as quoted strings, not long strings (§1).
   - Core decodes `payload`, checks `sig` over the decoded bytes, and only then hands them to the strict parser.
   - The payload is never passed to `loadstring`.
3. **Domain separation.** Sign `"pagle-pushed-content:1\n" .. payload`, so a signature made for one purpose can't be replayed as another.
4. **Inside the signed payload:**
   - `kid`, repeated, so moving the outer one breaks the check;
   - `seq`, a monotonic issue number;
   - `issuedAt` and `expiresAt` (server time);
   - the content.

   Core rejects a payload whose `seq` is below the highest it has accepted. That stops a downgrade to an older, validly signed file. The highest `seq` lives in SavedVariables.
   - This fits the map's rule that **Core logs each pushed event the first time it sees it**. A rebuild then reads the Catch log, never the companion's file.
5. **A manifest when content grows.** If payloads become tens of KB or several files, sign one small manifest of `{name, sha256}` entries, then hash each part.
   - The signature step stays at about 5 ms.
   - Hashing costs about 0.3–0.5 ms per KB.
6. **Put the check in Core `logic/`, in plain Lua 5.1.** The backend folds with lua5.1 (backend ADR 0003), so it can run the same check and the same test vectors.
   - Test against RFC 8017 and Wycheproof RSA PKCS#1 v1.5 vectors [P][8][10].
   - Also test against signatures the backend's own JDK signer makes.

---

## 6. How the public key ships and rotates

- **Where it lives.** A table in Core, keyed by key ID: `{ ["2026a"] = { n = "<hex>", e = 65537, rr = "<hex R^2 mod n>" }, ... }`. It ships with each addon release.
  - The public key is public. Nothing about it needs hiding.
  - A player who edits Core can swap the key, but they can equally edit anything local. Signatures protect honest players from forged or tampered files; they don't stop the player cheating themselves. Checking progress for leaderboards is the backend's job, out of scope in map #277.
- **Several keys at once.** Ship the current key and the **next** one. The backend can then switch to `next` at any time without waiting for players to update.
  - A file with an unknown `kid` is rejected the same way as a bad signature. Core shows nothing and logs it once.
- **Planned rotation, through releases:**
  1. Release N ships keys A (current) and B (next).
  2. The backend starts signing with B.
  3. Release N+1 ships B and C and drops A.
- **Leaked key.** Ship a release that drops it. Until players update, the leaked key still works, and **no addon-side revocation can be faster**: the addon has no network, and its only input is the companion's file.
  - What bounds the damage is `expiresAt`. Hunt Events last 3 days, so a short validity (for example 7 days) fits.
  - The highest-`seq` rule also blocks replays of old files.
- **Don't** fetch keys from the companion's file. A key delivered alongside the data it vouches for proves nothing.

---

## 7. Recommendation and fallbacks

**Recommended:** RSA-2048, PKCS#1 v1.5 with SHA-256, e = 65537. The backend signs with `SHA256withRSA`; the companion relays the bytes; Core checks them in `logic/`.

- Core's check is our own Montgomery modexp (24-bit limbs in doubles, no `bit`), with SHA-256 adapted from sha2.lua (MIT).
- The rule is re-encode and compare the whole block.
- `R^2 mod n` ships with the key.
- Run the check once per login (or once per new `seq`), from a coroutine that yields every few Montgomery multiplications.
- Cost: about 6–7 ms in stock Lua 5.1.5, so perhaps 15–35 ms in the client, once.

**Fallbacks, in order:**

1. **Ed25519 with ported ccryptolib (MIT).** Use it if the backend or companion side prefers small keys, or RSA hits a snag.
   - Similar cost (about 4 ms plus SHA-512).
   - Add the `S < L` check.
   - Swap in sha2.lua's SHA-512, about 2–3 ms against ccryptolib's 10 ms under the shim.
   - Restrict the shim to the eight real `bit` names.
2. **If the in-client cost proves high.**
   - Verify only when the content changes: keep the SHA-256 and `seq` of the last verified payload, and re-hash at login (1–2 ms) instead of re-checking the signature.
   - And/or sign a manifest (§5).
   - Chunking already keeps every slice well under a frame.
3. **Hash-only, for content known at release time.** For the calendar shipped in the addon, its own files are the trust root and need no check.
   - Hashes baked into a release can't vouch for content pushed after it, so this is no substitute for signatures on pushed Hunt Events.
   - A symmetric MAC (HMAC) is no better. Its secret would ship in the addon, readable by anyone.

## 8. Open questions, to settle in the client

- **The real cost.** Time the check in the client with `debugprofilestop()`: one RSA-2048 verify plus SHA-256 over 4 KB and 64 KB. Add it as a dev-probe check next to check 20 (`addons/Pagle/logic/Probe.lua`), and record it in the launch re-verification checklist.
- **The client's `bit` semantics.**
  - Whether results are signed or unsigned.
  - Whether `bxor` takes more than two arguments.
  - What `bit.mod` does with negatives.

  These only matter if a hash uses `bit`. The RSA bignum doesn't.
- **Whether "script ran too long" can trigger in `PLAYER_LOGIN`/`ADDON_LOADED` handlers on Forever for about 30 ms of work.** No source gives the limit. The coroutine design makes the answer irrelevant, but the probe should report the longest slice.
- **What `C_EncodingUtil.DecodeBase64` does with bad input**, and whether it exists on live Forever, not just beta build 70338. Keep a pure-Lua decoder in `logic/` either way, for the backend and the specs.

---

## Sources

1. Lua functions — https://warcraft.wiki.gg/wiki/Lua_functions [P]
2. Ketho/BlizzardInterfaceResources, branch `forever`, commit c5a49d39 (build 1.60.1.70338), `Resources/GlobalAPI.lua`: `bit.*` lines 6910–6917, `loadstring` 6946, `debugprofilestop` 6864, `C_EncodingUtil.*` around 1536 — https://github.com/Ketho/BlizzardInterfaceResources/tree/forever [P]
3. Lua 5.1 Reference Manual §2.1 (lexical conventions: escapes, long brackets) — https://www.lua.org/manual/5.1/manual.html#2.1 [P]
4. WoWInterface, "script ran too long" out of combat after 7.2.5 — https://wowinterface.com/forums/showthread.php?p=323998 [C]
5. WoWInterface, "script ran too long" at login with large LoD addons — https://wowinterface.com/forums/showthread.php?p=337647 [C]
6. RFC 8032, Edwards-Curve Digital Signature Algorithm (EdDSA): §5.1.7 Verify, §7.1 test vectors, §8.4 malleability — https://www.rfc-editor.org/rfc/rfc8032 [P]
7. migeyel/ccryptolib, commit 14489aa1 (2026-08-24): `ccryptolib/ed25519.lua`, `internal/{fp,fq,edwards25519,sha512,packing}.lua`, MIT — https://github.com/migeyel/ccryptolib [P]
8. RFC 8017, PKCS #1 v2.2: §3.1 (e between 3 and n − 1), §8.2.2 RSASSA-PKCS1-V1_5-VERIFY, §9.2 EMSA-PKCS1-v1_5 — https://www.rfc-editor.org/rfc/rfc8017 [P]
9. Java Security Standard Algorithm Names (JDK 21): `SHA256withRSA`, `Ed25519` — https://docs.oracle.com/en/java/javase/21/docs/specs/security/standard-names.html [P]
10. C2SP/Wycheproof test vectors (`rsa_signature_2048_sha256_test.json`, `ed25519_test.json`) — https://github.com/C2SP/wycheproof [P]
11. JEP 339: Edwards-Curve Digital Signature Algorithm (delivered in JDK 15) — https://openjdk.org/jeps/339 [P]
12. Egor-Skriptunoff/pure_lua_SHA, `sha2.lua` at commit 6adac177 (2022-03-02), MIT; library detection at lines 139–147, the `rol`/`ror` assert at line 221 — https://github.com/Egor-Skriptunoff/pure_lua_SHA [P]
13. philanc/plc, Pure Lua Crypto, README (Lua 5.3+, performance table) — https://github.com/philanc/plc [P]
14. BernhardZat/pure-lua-5.1-crypto — https://github.com/BernhardZat/pure-lua-5.1-crypto (seen through search results only)
15. RaiderIO/raiderio-addon, commit 97500366 (2026-10-18), `core.lua` lines 1020–1021 — https://github.com/RaiderIO/raiderio-addon [P]
16. exceptionptr/tsm-app-linux, commit 60ad454b (2026-09-24), `tsm/wow/lua_writer.py` and `docs/data.md` — https://github.com/exceptionptr/tsm-app-linux [S]
17. TSM support: AppData.lua — https://support.tradeskillmaster.com/addon/how-do-i-fix-an-error-about-appdatalua-being-empty [P]
18. WeakAuras/WeakAuras2, commit a690a22f (2026-10-12), `WeakAuras/WeakAuras.lua` lines 1048–1064 and `WeakAuras/Transmission.lua` lines 217–358 — https://github.com/WeakAuras/WeakAuras2 [P]
19. LibHash for WildStar (CurseForge) — https://www.curseforge.com/wildstar/ws-addons/libhash [C]
