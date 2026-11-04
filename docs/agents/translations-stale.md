# Translations stale: drift, the drop and the per-language issue

How a stale translation is found, dropped and tracked (ADR 0019, "Coverage, `listed` and drift"; DATA-R114 Drift; translators' side in [docs/translations.md](../translations.md), "Drift and the stale issue"). All of it is `scripts/generate-data.py`; the code is `scripts/pagle_data/drift.py` and `toml_edit.py`, and `scripts/tests/test_drift.py` and `test_toml_edit.py` test it.

A translated string carries `en`, the English it was translated from. When English changes, `en` stops matching and the string is **stale**, of one of two kinds: **same fields** (the `{field}` set is unchanged; the old translation keeps showing) or **fields changed** (it no longer fits; it is dropped so English shows). A change to English never waits for a translator.

## The commands

| Command | What it does |
|---|---|
| `--stale` | Writes nothing, exits 0. Lists, per language, every stale string, interface and Lore, fields changed first. `--json` for a script. |
| `--drop-stale` | Removes every fields-changed string from its TOML, then regenerates like a plain run. Run it in the PR that changes English. |
| `--stale-issue CODE` | Writes nothing. Prints the body of the language's "translations stale" issue. `--json` prints `title`, `body` and the counts. |

Run each as `.tools/bin/python scripts/generate-data.py <flag>`. They read the TOML themselves, so they work on a tree where the plain generator fails on the stale string. A plain run on such a tree fails the placeholder check (or the newline or shape check) and ends with a line that says to run `--drop-stale`.

## When you change English (the maintainer or an agent)

1. Change the English TOML (`data/locale/enUS/`, `data/lore/`, or the Hunt text beside its definitions).
2. Run `--stale` to see what the change made stale, in every language.
3. Run `--drop-stale`. It drops the fields-changed strings and regenerates. Commit the TOML and the generated files it touched with your change.
4. Run `--check`. It passes without any translator: a same-fields string stays stale and only warns.

`--drop-stale` edits by line (`toml_edit.py`): comments, order and line endings stay; it proves its edit against the original and stops, writing no file, if it cannot. A comment that sat above a dropped entry stays where it was; delete it by hand if it no longer fits. A second run changes nothing.

## The issue for each language

Once a language is listed it stays listed, and its gaps and stale strings are tracked in one issue, titled `Translations stale: <code>` (`drift.issue_title`). The body is the counts, the stale strings by kind (each with the English now and the English it was translated from), the interface keys with no text (counting the fallback chain, as coverage does), and, for each Lore file the language has, how many English keys it lacks (a count only: Lore is optional). It is deterministic, so an unchanged issue is not edited. It is cut to fit GitHub's limit: the English beside each key goes first, then the tail of the list.

**Who writes it.** The `Translations stale` workflow (`.github/workflows/translations-stale.yml`) does, every Monday at 06:30 UTC and on request (`workflow_dispatch`), for each listed language: it opens the issue when there is something to track, rewrites the body of an existing one, closes it when nothing is stale or missing, and reopens it when English moves again. It has two triggers and no event trigger on purpose: an `issues` trigger would start a run for every issue. By hand, an agent or the maintainer can do the same with `gh`:

```
.tools/bin/python scripts/generate-data.py --stale-issue esES --json > issue.json
gh issue list --state all --search 'in:title "Translations stale: esES"' --json number,title,state
gh issue create --title "$(jq -r .title issue.json)" --body "$(jq -r .body issue.json)"    # none yet
gh issue edit <number> --body "$(jq -r .body issue.json)"                                    # one exists
```

(Mind the `gh` notes in [issue-tracker.md](issue-tracker.md).)

## The label

The issue proposes the label `translations-stale` for these issues. **The label does not exist yet, and creating a repository label is the maintainer's decision**: neither the workflow nor an agent creates it. The workflow puts it on a new issue if the repository has it and does without otherwise. To adopt it: `gh label create translations-stale --description "A language's strings are stale or missing (DATA-R114)"`; issues already open can be labelled by hand, and the workflow does not relabel an existing issue.
