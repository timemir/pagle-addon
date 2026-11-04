<!-- translations-stale: esES -->
English has changed since some of Español's (`esES`, not listed yet) strings were translated, or has strings this language has no text for yet. Update a stale string's `value` and its `en` snapshot together, in the file named beside it. The list is written by `scripts/generate-data.py --stale-issue esES` and rewritten from the files, so a string leaves it when it is fixed (docs/translations.md, docs/agents/translations-stale.md).

| | Strings |
|---|---|
| Stale, fields changed (English shows until retranslated) | 3 |
| Stale, same fields (the old translation still shows) | 2 |
| Interface keys with no translation (English shows) | 2 of 9 |
| Lore keys with no translation, in the Lore files it has (English shows) | 7 |

## Stale: fields changed (3)

The `{fields}` of the English text changed (or its line breaks or shape), so the translation no longer fits and cannot stay. The maintainer's `--drop-stale` removes it and English shows until it is translated again.

- [ ] `data/locale/esES/core.toml` `FISH_COUNT`: now `{"one": "{count} fish", "other": "{count} fishes in {zone}"}`, was `{"one": "{count} fish", "other": "{count} fishes"}`
- [ ] `data/locale/esES/core.toml` `SEAL`: now `%s\nof\n%s`, was `%s\nof %s`
- [ ] `data/lore/esES/ledger.toml` `title.zonemaster.text`: now `Master of {zone}, {fish}`, was `Master of {zone}`

## Stale: same fields (2)

The English wording changed and the `{fields}` did not, so the old translation keeps showing. Check it still says what the English now says.

- [ ] `data/locale/esES/core.toml` `GREETING`: now `Hi, {name}`, was `Hello, {name}`
- [ ] `data/lore/esES/ledger.toml` `species.13759.riddle`: now `Bites where the water runs slow.`, was `Bites where the water runs lazy.`

## Interface keys with no translation (2)

These show English. Add each to its addon's file.

- [ ] `core.COLOUR`
- [ ] `hunts.HUNTS_ONLY`

## Lore

Lore is optional: a key with no translation shows English. How many keys each Lore file has no translation for:

- `data/lore/esES/ledger.toml`: 7 of 11
