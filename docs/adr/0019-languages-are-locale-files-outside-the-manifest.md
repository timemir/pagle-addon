# Languages are locale files that stay outside the manifest

Amends ADR 0001.

Pagle's interface and Lore are English only in 1.0. From 1.1 a player can read Pagle in another language, and a translator can add one without a new release policy. A language is data: a **Locale** of generated Lua registration files that overlay each addon's string table (`ns.L`), chosen by a player setting. It is not code, and it never reaches the files the backend hashes.

This design is for 1.1. Nothing here changes 1.0.0 or 1.0.1.

## The mechanism

- **Source:** UI strings and translated Lore are TOML. `data/locale/<code>/*.toml` holds the interface text (enUS too, after a one-time conversion of today's `locale/enUS.lua`), and `data/lore/<code>/*.toml` holds Lore. `<code>` is always the full client code (`enUS`, `deDE`, `esES`), never a short form. Next to each translated string sits an `en` field, the **EN snapshot** of the English it was translated from.
- **Generator:** `scripts/generate-data.py` validates the TOML and writes `addons/<Addon>/locale/<code>.lua` for the interface and `addons/<Addon>/data/Lore.<code>.lua` for Lore. `locale/enUS.lua` becomes generated output. The generator validates coverage, the `listed` flag, the plural rule, the number separators, the EN snapshots, each string's `{field}` set, the lengths and the glyphs, and writes them into the locale file.
- **Registration:** a locale file calls `ns.Locale("esES", function(L) … end)` and gives the language's plural rule, its decimal and thousands separators, and its fallback (esMX falls back to esES). Only the function of the chosen language runs, and it writes into `ns.L` in place, because about 36 files cache `local L = ns.L`.
- **Loading:** each TOC gets one stable line, `locale\Locales.xml`, after `locale\enUS.lua` and `data\Lore.lua`. The XML lists the locale files as `<Script>` entries. A new language adds a locale file and a line in that XML, and no TOC line.

A translator's path is therefore: add a TOML directory, run the generator, open a PR.

## The language setting and when it applies

One **Language setting** lives on Core's Settings root, account-wide: "Game default", English, and each listed language by its own name. Changing it asks for a `/reload`. Modules follow Core and have no setting of their own.

- **Fallback chain:** if `PagleDB` is absent or unreadable, the setting counts as "Game default". "Game default" means the client's locale when that language is listed, else English. Any string a language lacks shows its English.
- **Core applies it first.** Core's files run before SavedVariables exist, and its `ADDON_LOADED` handler (`adapter/Login.lua`) calls `StartRecovery()` and then `OpenSavedVariables()`, which prints `L.LOG_UNREADABLE`. The overlay must run before both. It reads the language from the raw `_G.PagleDB` table, before AceDB wraps it, so the order of Core's `ADDON_LOADED` work gains one step in front of everything that prints.
- **Modules apply at file load.** A Module's files run after Core's `ADDON_LOADED` (CORE-R10), so Core already knows the setting.
- **No top-level reads.** About fifteen `L` reads happen when a file loads, before any overlay could run. They move inside functions. A guard spec fails any new top-level read, by listing the main chunk of each file with `luac -l`.

Only languages the current client can render are offered (see the scripts and fonts section). `esES` also serves `esMX` until a separate `esMX` exists, which then overlays it.

## Why a new language stays outside the manifest

The backend's ranked manifest hashes the addon's `logic/` files, three `data/` files and the six TOCs. It hashes no `locale/` file, no `Lore*.lua` file and no `.xml` file, and pagle-backend has been asked to keep those out from its next policy on. Three choices keep it that way:

- **One stable TOC line.** The TOCs never name a language. They carry no `## Title-xx` or `## Notes-xx` lines either; the TOCs stay English.
- **Plural rules live in the locale files.** A language's CLDR plural rule is data in its own locale file, never code in `logic/`, so a new language touches no hashed file.
- **The helper is code, once.** The only hashed change is the one that makes this possible, and it lands in 1.1.

A translation PR then changes only unhashed files, and a release that ships one needs no policy of its own.

## The text helper

Core owns one text helper and exposes it on its Module API (ADR 0001). It takes **named fields** (`{fish}`, `{count}`), never `%s` or positional arguments, so a translator can reorder them. It also does:

- **CLDR plural selection** through the active locale's plural rule, with the categories that language needs (`one`, `few`, `many`, `other` and so on) instead of the binary `n == 1`;
- **number formatting** with the separators the chosen Pagle language declares, not the client's.

It replaces `string.format`, `ns.Fill`, `ns.Plural` and the `_ONE`/`_OTHER` key pairs across about 134 files. A converter script rewrites enUS to the new form and converts #510's esES files too, regenerating their EN snapshots in the same pass so the drift check does not mark every Spanish string stale on the first day.

Other English assumptions move with it: ASCII-only `:upper()` and `:lower()` (small caps, search, the Tour's three-letter test), the `ringOf` and `STAMPS` lookups by English words, the date from `client.Date("%b")`, the `", "` joins, articles in `RARITY_NAMES`, `GUIDE_COUNT_WORDS`, the "s" plural, and the Recovery and slash strings that sit outside `ns.L`.

## Scripts and fonts

The bundled faces cover Latin-1 and Latin Extended-A, and Caveat also covers Cyrillic. CORE-R9 becomes a set per file kind and locale. `logic/`, `adapter/`, TOC and XML files keep today's set. A locale file and a Lore file may use the range of their script.

- **Latin scripts** use the bundled faces.
- **Cyrillic, Korean and Chinese** (ruRU, koKR, zhCN, zhTW) swap every face to the client's own fonts, through a per-locale font table in Core. Pagle bundles no fonts for those scripts.
- **The font probe.** No code references a client font except the `FRIZQT__.TTF` fallback, and there is no evidence yet of which font files exist on clients of other languages. `/pagle dev fonts` tries `SetFont` on each known client font path, to be run on an enUS client and on a deDE client. Until it shows otherwise, a non-Latin language is offered only on its own client. That is the 1.1 rule that implements "only languages the client can render are offered".
- **A pseudo-locale** for development pads text by about 40%, uses accents and Cyrillic, and wraps each string in brackets. A dev command switches to it. It proves that the layouts hold before a real language is offered.

Slash command words stay English.

## Coverage, `listed` and drift

- **Coverage.** The UI translation is required: a language is first **listed** only at 100% of the UI strings, and the maintainer then flips its `listed` flag. Lore is optional and falls back to English per key.
- **Once listed, always listed.** Later gaps show English, and a per-locale "translations stale" issue tracks them. "Game default" on a language that is not listed means English.
- **Drift.** An English change makes a translation stale. If the translation keeps the same `{field}` set, it keeps showing, the spec warns and a script lists it. If the field set changed, the maintainer's PR drops that translation by script, and the string falls back to English. CI never blocks an English change on a translator.
- **Length.** A translated Lore field may be at most the English limit plus 30%, counted in code points. The pseudo-locale covers the interface strings.
- **Review.** A translation PR needs one approval from another native speaker of that language. The maintainer reviews structure only: the checks pass, the files are in the right place.
- **Credits.** A TRANSLATORS section in each release's CHANGELOG entry, a "Translations" line on the Settings root, and the translators' names in the TOML header, which the generator carries into the locale file.

## What stays English

- Text the client supplies: item and zone names, item quality names, `ERR_*` strings. Pagle shows them in the client's language. The strip of "Raw " from item names stays gated on the client's locale.
- Dev, probe and diagnostic text, the Field report body and the slash command words.
- Pushed content: Pagle_Content and the backend's text stay English in 1.1. A per-locale field is a later change on the backend and the companion.
- Decoration inside art, which is not a string (SHOP-R20).

Everything else a player reads is translated, Recovery's text included, which moves into `ns.L` for it.

## Considered Options

- **Hand-written locale Lua with `-- EN:` comments, as #510 does.** Rejected: the generator that validates Lore could not validate the interface, and a comment is not a field it can check. TOML makes the EN snapshot a field.
- **A language chosen by the client's locale alone.** Rejected: the dev chose a player setting that is independent of the client.
- **`%s` and `string.format`, positional or not.** Rejected for named `{fields}` behind one helper. WoW's `string.format` accepts `%1$s`, but busted's Lua 5.1 does not, so the helper is also what the specs can run.
- **A language file named in each TOC, or `## Title-xx` lines.** Rejected: a hashed TOC would change for every new language.
- **Bundled fonts for Cyrillic, Korean and Chinese.** Rejected: those clients swap to their own fonts.
- **Shipping translations with 1.0.** Rejected: 1.0 is enUS, and the work touches about 134 hashed files, so it ships in 1.1 under one new policy.

## Consequences

- **One new release policy for 1.1.** The text helper, the lazy `L` reads and the converted strings change hashed files. It lands after 1.0.1's release commit, under one new policy that is picked with pagle-backend after 1.0.1. No policy is named here. After it, a new language needs none.
- **1.0 is unchanged.** enUS stays the only language, CORE-R8 and CORE-R9 keep their 1.0 meaning, and nothing in this design ships before 1.1.
- **The 1.1 work is large and mechanical** (about 134 files). It is tracked as an epic of its own, blocked by the 1.0.1 tag.
- **Translators need a native-speaker reviewer.** A language with one translator and no second native speaker cannot be merged.
- **Stale strings are visible but never fatal.** A translation can lag behind English for a while, and the player sees English or an older wording rather than a broken string.
- **A non-Latin language is limited by what the client carries.** Until the probe shows which fonts exist, it is offered on its own client only.
- **#510 needs one correction after this merges:** the concrete file shape and the converter's promise.

Triggered by [#510](https://github.com/timemir/pagle-addon/pull/510), the esES translation, which is held for 1.1. The specification is CORE-R8, CORE-R9, DATA-R104 and DATA-R114, and `docs/translations.md` is the translators' guide.
