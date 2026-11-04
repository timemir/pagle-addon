# Translating Pagle

This guide is for translators. The design behind it is [ADR 0019](adr/0019-languages-are-locale-files-outside-the-manifest.md).

Pagle is English only in 1.0. Translations arrive in 1.1. Where this guide says "from 1.1", the tooling does not exist yet, and nothing here is a command you can run today. This guide changes as the tooling lands.

## What you translate

- **The interface.** Every string a player reads in Pagle's windows, toasts, tooltips and settings. A language needs all of it before it is listed.
- **Lore** (optional). The names and lines of flavour Pagle invents: a fish's blurb and riddle, titles, plaques. Any key you leave out shows in English.

These stay English: the names the game supplies (items, zones, item quality, game errors), slash command words (`/pagle report`), developer and diagnostic text, the Field report text, and anything Pagle's backend pushes to the game.

## File layout

From 1.1, each language has a directory of TOML files named by its full client code (`esES`, `deDE`, `ruRU`), never a short form:

```
data/locale/<code>/*.toml     interface text, one file per addon
data/lore/<code>/*.toml       Lore, one file per addon
```

The English files are the source of everything else. Copy the `enUS` interface files into your directory and translate them. Lore files copy from `data/lore/*.toml`.

Next to each translated string sit two fields:

- **the value**, your translation;
- **`en`**, a snapshot of the English text you translated from. Copy it as it is in the English file at that moment. Do not translate it.

The generator reads these and writes the Lua files the game loads (`addons/<Addon>/locale/<code>.lua` and `addons/<Addon>/data/Lore.<code>.lua`). Never edit the generated files by hand. Put your name in the header of your TOML file; it is carried into the generated file and into the credits.

## Running the generator

From 1.1, run the data generator after every change to your files:

```
.tools/bin/python scripts/generate-data.py
```

(`.tools` is the toolchain that `scripts/setup.sh` installs.) It validates your files and rewrites the generated Lua. `--check` writes nothing and fails if a generated file is out of date. Commit your TOML and the generated files together.

## Checks that must pass

The generator fails with the key and the check name. Fix the TOML, never the check. Drift is the exception: it warns and does not fail (see Drift).

| Check | It fails when |
|---|---|
| missing | a required key has no text, or an empty one (interface text; Lore only where you chose to translate it) |
| orphan | you translated a key that does not exist in English, or that belongs to another addon |
| length | a Lore field is more than the English limit plus 30%, counted in code points (see below) |
| newline | a field holds a line break |
| placeholder | a `{field}` is not one the English text has, or one the English text has is missing |
| glyph | a character is outside what the client's fonts can draw for your script |
| coverage | the interface is below 100% and the language is marked `listed` |

## Plural categories and `{fields}`

Strings take named fields in braces, such as `{count}` or `{fish}`. Write the field exactly as the English does, and put it where your language needs it. Never use `%s` or positional arguments. Do not add a field the English text does not have.

A string with a count has one form for each plural category your language uses, following the CLDR rules. English has `one` and `other`; Spanish has `one`, `many` and `other`; Russian has `one`, `few`, `many` and `other`. Your language's rule, and its decimal and thousands separators, are declared in your language's file, so a new language never needs a code change. Write every category your language needs for each counted string.

## Length

The interface has little room. Keep a translation close to the English length. From 1.1 a development pseudo-locale (the English padded by about 40%, with accents and Cyrillic, in brackets) shows whether a layout holds.

A Lore field may be at most the English limit plus 30%. Count code points, not bytes: "ñ" is one. The limits are in `data/lore/VOICE.md`.

## Scripts and fonts

Pagle bundles fonts for Latin scripts (Latin-1 and Latin Extended-A, with Cyrillic in one face). Russian, Korean and Chinese use the client's own fonts, which Pagle switches to when that language is chosen. Until it is confirmed which fonts the other clients carry, a language in one of those scripts is offered only on its own client. A language in a Latin script has no such limit.

## Getting your language listed

1. Translate 100% of the interface. A language is first listed at 100% and not before.
2. Open a pull request with your TOML files and the generated files.
3. **One native speaker of your language who did not write it must approve the PR.** The maintainer then checks the structure only: the checks pass and the files are in the right place. The maintainer does not judge the translation.
4. The maintainer flips the language's `listed` flag. From then on players can choose it in Pagle's Language setting.

A language that is not listed is not offered. A player whose game language is unlisted sees English when the setting is "Game default".

`esES` also serves `esMX` until a separate `esMX` exists. A later `esMX` overlays it, and only needs the strings that differ.

## Drift and the stale issue

When the English text changes, your translation is stale. What happens next depends on the change:

- **The `{fields}` are the same.** Your translation keeps showing. A spec warns and a script lists it. Update the value and the `en` snapshot together.
- **The `{fields}` changed.** The maintainer's PR drops your translation by script, so the player sees English until you translate it again.

A listed language stays listed. Gaps show English, and a "translations stale" issue for the language tracks them. A change to English never waits for a translator.

## Credits

Your name goes in your TOML file's header. Each release's CHANGELOG has a TRANSLATORS section, and a "Translations" line on Pagle's Settings root credits the translators.
