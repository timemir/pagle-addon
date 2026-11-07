# Translating Pagle

This guide is for translators. The design behind it is [ADR 0019](adr/0019-languages-are-locale-files-outside-the-manifest.md).

Pagle is English only in 1.0. Translations arrive in 1.1. The tooling this guide describes is part of the 1.1 work: the commands below run on the `i18n/1.1` branch, and on `main` once 1.1 has merged. Where this guide says "from 1.1", it is not in the 1.0 release.

## What you translate

- **The interface.** Every string a player reads in Pagle's windows, toasts, tooltips and settings. A language needs all of it before it is listed.
- **Lore** (optional). The names and lines of flavour Pagle invents: a fish's blurb and riddle, titles, plaques. Any key you leave out shows in English.

These stay English: the names the game supplies (items, zones, item quality, game errors), slash command words (`/pagle report`), developer and diagnostic text, the Field report text, and anything Pagle's backend pushes to the game.

## File layout

From 1.1, each language has a directory named by its full client code (`esES`, `deDE`, `ruRU`), never a short form:

```
data/locale/<code>/locale.toml    the language's header
data/locale/<code>/<addon>.toml   interface text, one file per addon
data/lore/<code>/*.toml           Lore, one file per addon
```

The addon files are `core`, `hunts`, `ledger`, `qol`, `stats` and `tackleboard`. The English files in `data/locale/enUS/` are the source of everything else. Copy the ones you translate into your directory and translate them. Lore files copy from `data/lore/*.toml` and are named by lore ID (`core`, `ledger`, `hunts`, `stats`, `tackleboard`; QoL has no Lore). A Lore file only works beside the interface file of the same addon: `data/lore/esES/ledger.toml` needs `data/locale/esES/ledger.toml` (and the header), because the interface file is what registers your language for that addon.

**The header** (`locale.toml`) says who the language is:

```toml
name = "Español"                  # the language's own name, shown in the Language setting
translators = ["Ana", "Luis"]     # your GitHub names; carried into the generated file and the credits
listed = false                    # the maintainer flips this (see "Getting your language listed")
plural = "one_many_other"         # the CLDR plural rule, by name (see Plural categories)
decimal = ","
thousands = "."
fallback = "esES"                 # optional: a language that falls back to another (esMX to esES)
```

With a `fallback`, give only the fields that differ: the rest come from the language it falls back to.

**A translated string** is a table with the translation and, beside it, `en`, a snapshot of the English text you translated from. Copy `en` as it is in the English file at that moment. Do not translate it.

```toml
[BOARD]
value = "Cacerías"
en = "Hunts"

[FISH_COUNT]
value.one = "{count} pez"
value.many = "{count} de peces"
value.other = "{count} peces"
en.one = "{count} fish"
en.other = "{count} fishes"
```

A value is text, or a list of text (`value = ["Pequeño", "Grande"]`), or a table of text (`value.0 = "Reinos del Este"`, the `0` being the key the code reads). Whatever English has at a key, you have the same: a list of the same length, a table with the same keys. The entry replaces English's whole, so a list missing an item would leave a hole in the game.

**Lore** keeps English's tables and field names, and each field is its own table with `value` and `en`, so a field that changes in English is flagged on its own:

```toml
[species.6362.blurb]
value = "Un sargo que trasnocha."
en = "A snapper that keeps late hours."

[species.6362.riddle]
value = "Pica donde el agua corre perezosa."
en = "Bites where the water runs lazy."

[good."core.toaststyle.page".name]
value = "Página rasgada"
en = "Torn Page"
```

An ID with dots is quoted, as in the English file. A bare `blurb = "…"` is a shape error. Leave out any key you have not translated: it shows English. Lore text is plain text, never an array or a count. Hunts, Hunt sets and Hunt Events keep their English text beside their definitions in `data/hunts/`, but you translate all of it in `data/lore/<code>/hunts.toml` under the same keys the game uses (`hunt.<id>.name`, `set.<id>.title`, `event.<id>.note`, `huntgood.<id>.description`); look the keys up in `addons/Pagle_Hunts/data/Lore.lua`.

The generator reads these and writes the Lua files the game loads (`addons/<Addon>/locale/<code>.lua`, `addons/<Addon>/locale/Locales.xml` and `addons/<Addon>/data/Lore.<code>.lua`). Never edit the generated files by hand. Put your name in the header; it is carried into the generated file and into the credits.

## Running the generator

Run the data generator after every change to your files:

```
.tools/bin/python scripts/generate-data.py
```

(`.tools` is the toolchain that `scripts/setup.sh` installs.) It validates your files and rewrites the generated Lua. `--check` writes nothing and fails if a generated file is out of date, or if a check below fails. Commit your TOML and the generated files together. Warnings (stale snapshots, gaps in a language that is already listed) print and do not fail; `--stale` lists the stale ones (see Drift).

The coverage check compares your language with the branch your pull request merges into. In CI that is automatic; to run it yourself, add `--base origin/main` (or whichever branch you are merging into).

## Checks that must pass

The generator fails with the key and the check name. Fix the TOML, never the check. Drift is the exception: it warns and does not fail (see Drift).

| Check | It fails when |
|---|---|
| missing | a value is present but empty (interface text; Lore only where you chose to translate it). A key you have not translated at all is not a failure; it is a gap, and shows English |
| orphan | you translated a key that does not exist in English, or that belongs to another addon's file |
| length | a Lore field is more than the English limit plus 30%, counted in code points (see Length) |
| newline | a text has a different number of line breaks than the English text: keep the breaks English has, and add none (Lore has none at all) |
| placeholder | a `{field}` is not one the English text has, or one the English text has is missing. In Lore the fields are `{zone}` and `{fish}` only, and any other `{` or `}` fails |
| plural | a counted string lacks `other` or a category your language's rule uses, or has one the rule never gives |
| shape | an entry is not `value` and `en`, or its list or table is not the shape of English's |
| glyph | a character is outside what the client's fonts can draw for your script |
| registration | a Lore file has no interface file for the same addon (and the header) in `data/locale/<code>/` to register your language |
| header | the header has an unknown or missing field, a plural rule that is not in the table, equal separators, or a fallback that does not exist |
| coverage | your language is marked `listed`, was not listed on the branch you are merging into, and is below 100% of the interface |

Coverage is the only check that depends on where you are merging. A language that is already listed and falls below 100% because English added a string only gets a warning, so an English change never waits for a translator.

## Plural categories and `{fields}`

Strings take named fields in braces, such as `{count}` or `{fish}`. Write the field exactly as the English does, and put it where your language needs it. Never use `%s` or positional arguments. Do not add a field the English text does not have.

A string with a count has one form for each plural category your language uses, following the CLDR rules. English has `one` and `other`; Spanish has `one`, `many` and `other`; Russian has `one`, `few`, `many` and `other`. Your language's rule, and its decimal and thousands separators, are declared in your language's header, so a new language never needs a change to the game's code. The rule is a name from the generator's table, `scripts/pagle_data/plural.py`: `other` (Japanese, Korean, Chinese), `one_other` (English, German, Dutch), `one_many_other` (Spanish, Italian), `one_many_other_01` (French, Portuguese) and `one_few_many_other` (Russian, Ukrainian). A language the table lacks needs a new rule added there, with a test; ask in your pull request. Write every category your language needs for each counted string, and `other` always.

How the helper reads a string:

- `{count}` is the field that holds the number a counted string is about. Keep it in every form. The helper picks the form by your language's rule applied to `count`, and uses `other` where a form is missing, so `other` is always required.
- `{name}` writes the value as it is. A number that should read with your language's separators is written `{name:n}` (as it is), or `{name:0}`, `{name:1}`, `{name:2}` for a fixed number of decimal places. Keep the spec the English uses, unless your language needs a different number of decimals; the check compares field names, not specs.
- To write a literal brace, double it: `{{` and `}}`. Reorder fields freely.
- A field the helper has no value for shows as written, so a typo in a name is visible in the game rather than blank.
- The decimal and thousands separators are the ones your language declares (`1.234,5` where the decimal is `,` and thousands `.`), never the player's client's.

## Length

The interface has little room. Keep a translation close to the English length. From 1.1 a development pseudo-locale (the English padded by about 40%, with accents and Cyrillic, in brackets) shows whether a layout holds: `/pagle dev on`, `/pagle dev pseudo on`, then `/reload`. Fields, colour codes and textures are left as they are.

A Lore field may be at most the English limit plus 30%. Count code points, not bytes: "ñ" is one. The limits are in `data/lore/VOICE.md`. The allowance is the limit times 13, divided by 10, with the fraction dropped: a name (28) may be 36 characters, a title (32) 41, a riddle (80) 104, a plaque (100) 130 and a blurb (200) 260. A field English leaves unlimited has no limit in your language either.

## Scripts and fonts

Pagle bundles fonts for Latin scripts (Latin-1 and Latin Extended-A, with Cyrillic in one face). Russian, Korean and Chinese use the client's own fonts, which Pagle switches to when that language is chosen. Until it is confirmed which fonts the other clients carry, a language in one of those scripts is offered only on its own client. A language in a Latin script has no such limit.

## Getting your language listed

1. Translate 100% of the interface, every key of every addon's file. A language is first listed at 100% and not before: the coverage check fails a pull request that marks a language `listed` below it.
2. Open a pull request with your TOML files and the generated files.
3. **One native speaker of your language who did not write it must approve the PR.** The maintainer then checks the structure only: the checks pass and the files are in the right place. The maintainer does not judge the translation.
4. The maintainer flips the language's `listed` flag in `locale.toml`, in a pull request of its own. From then on players can choose it in Pagle's Language setting.

A language that is not listed is not offered. A player whose game language is unlisted sees English when the setting is "Game default".

For 1.1 the maintainer listed Spanish (`esES`) and Russian (`ruRU`) before step 3: parts of both are machine-drafted (all of Russian, and the Spanish strings #510 didn't have), and they await a native speaker's review. For 1.1.1 German (`deDE`) joined them the same way, all of it machine-drafted. Corrections are welcome as ordinary pull requests.

`esES` also serves `esMX` until a separate `esMX` exists. A later `esMX` overlays it, and only needs the strings that differ.

## Drift and the stale issue

When the English text changes, your translation is stale; in Lore, that is a field whose `en` is no longer the English text. What happens next depends on the change:

- **The `{fields}` are the same.** Your translation keeps showing. A spec warns and a script lists it. Update the value and the `en` snapshot together.
- **The `{fields}` changed.** The maintainer's PR drops your translation by script, so the player sees English until you translate it again. The same goes for an English change that makes your text fail the line-break or shape check (English gained a line break, or became an array): the generator would fail it, and an English change never waits for a translator.

A listed language stays listed. Gaps show English, and a "translations stale" issue for the language tracks them. A change to English never waits for a translator: the generator only warns about the gaps of a language that is already listed.

**Listing the stale strings.** `.tools/bin/python scripts/generate-data.py --stale` writes nothing and exits 0. For each language it lists every translated string (interface and Lore) whose `en` is no longer today's English, first the ones whose fields changed and then the ones that keep showing, each with the English you translated from (`was`) and the English now (`now`). `--stale --json` prints the same as JSON for a script. It reads the TOML directly, so it works on a tree where the generator itself fails because of a stale string. A spec (`scripts/tests/test_repo_stale.py`) raises one pytest warning for each, and never fails.

**Dropping the strings whose fields changed.** The maintainer's PR that changes English runs `.tools/bin/python scripts/generate-data.py --drop-stale`. It removes the `value` and the `en` of every translation whose fields changed, from the language's TOML, then regenerates like a plain run, so the PR is green without waiting for a translator and `--check` passes. Until it runs, a plain generator run fails the placeholder check for such a string and says to run it. The edit is by line: it deletes the entry's lines and nothing else, so comments (including one that was about the dropped entry), order and line endings stay, and it checks its own result against the original and stops rather than write a file it cannot prove. Running it a second time changes nothing. Strings with the same fields stay, stale, and are what the issue below tracks.

**The stale issue.** Each listed language has one issue, "Translations stale: esES", that tracks what its translators owe: the counts, the stale strings by kind and the interface keys it has no text for, each as a checklist item (Lore gaps only as counts, since Lore is optional). `.tools/bin/python scripts/generate-data.py --stale-issue esES` prints its body, and `--json` adds the title and the counts. The "Translations stale" workflow writes these issues every Monday and on request from the Actions tab: it opens the issue for a language that has something to track, rewrites it from the files each time, closes it when nothing is stale or missing, and reopens it when English moves again. It puts the `translations-stale` label on a new issue only if the repository has that label; creating it is the maintainer's call. To fix a string, update its `value` and `en` in the file the issue names; it leaves the list at the next run. How the process works for the maintainer and for an agent is in [docs/agents/translations-stale.md](agents/translations-stale.md).

## Credits

Translators are credited in three places, all from the `translators` array in your language's header. Give your GitHub name, the one you commit under: names are held to your language's glyph range (the generator fails a name the game's fonts would draw as boxes), and GitHub names are plain ASCII, which every language has.

- **The generated file.** The generator writes the names into `addons/<Addon>/locale/<code>.lua`, as a comment and in the registration (`ns.LocaleInfo(code).translators`).
- **The Settings root.** A "Translations" line after the Catch log row, from 1.1, reads "Translations: Deutsch by Max; Español by Ana, Luis". It lists the translators of each listed language, by the language's own name, in the order of the client codes. It credits a language only where the client can render it (the same rule as the Language dropdown), so a Russian translator is credited on a Russian client, and the line is not there at all while no listed language has translators. A language that is not listed is not credited.
- **The CHANGELOG.** A release entry has a `### TRANSLATORS` block only when that release changes a listed language's translations: any file under `data/locale/<code>/` or `data/lore/<code>/`, its `locale.toml` included, that differs from the previous release tag. The block comes after the entry's introduction and before its first addon section, with one line for each such language that has translators, in the order of the client codes, and a release that changes no translations has none. A block looks like this:

  ```md
  ### TRANSLATORS

  - Deutsch: Max
  - Español: Ana, Luis
  ```

  The release author does not write it by hand. `.tools/bin/python scripts/generate-data.py --translators --since <previous tag>` prints it from the headers for the languages whose translations changed since that tag (without `--since`, for every listed language with translators), and the author pastes it into the entry. Before the tag, `.tools/bin/python scripts/generate-data.py --check-changelog <version>` compares with the previous release tag and fails the entry for that version if it lacks the block or a line for a language whose translations changed, or if it credits a language whose translations did not change; an entry that changes none needs no block. With no release tag before the version, it wants a line for every listed language with translators. It judges the one entry it is given, never a past one, and is run by hand at release (the gate does not run it, since the entry is written only when the release is). Past entries are never edited when a translator joins: adding a name changes the language's `locale.toml`, so the next release's block carries the new names.
