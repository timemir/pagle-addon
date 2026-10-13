"""A tiny VMaNGOS world database for the baseline extractor's tests (DATA-R9).

Only the tables and columns scripts/extract-baseline.py reads, with the dump's names and defaults (patch_min 0,
patch_max 10, as in db_latest@4641790). Each row is written as the test needs it; build() returns the file.
"""

import sqlite3
from collections.abc import Sequence
from pathlib import Path

_SCHEMA = """
CREATE TABLE fishing_loot_template (
  entry integer NOT NULL, item integer NOT NULL, ChanceOrQuestChance float NOT NULL DEFAULT '100',
  groupid integer NOT NULL DEFAULT '0', mincountOrRef integer NOT NULL DEFAULT '1',
  maxcount integer NOT NULL DEFAULT '1', condition_id integer NOT NULL DEFAULT '0',
  patch_min integer NOT NULL DEFAULT '0', patch_max integer NOT NULL DEFAULT '10');
CREATE TABLE reference_loot_template (
  entry integer NOT NULL, item integer NOT NULL, ChanceOrQuestChance float NOT NULL DEFAULT '100',
  groupid integer NOT NULL DEFAULT '0', mincountOrRef integer NOT NULL DEFAULT '1',
  maxcount integer NOT NULL DEFAULT '1', condition_id integer NOT NULL DEFAULT '0',
  patch_min integer NOT NULL DEFAULT '0', patch_max integer NOT NULL DEFAULT '10');
CREATE TABLE gameobject_loot_template (
  entry integer NOT NULL, item integer NOT NULL, ChanceOrQuestChance float NOT NULL DEFAULT '100',
  groupid integer NOT NULL DEFAULT '0', mincountOrRef integer NOT NULL DEFAULT '1',
  maxcount integer NOT NULL DEFAULT '1', condition_id integer NOT NULL DEFAULT '0',
  patch_min integer NOT NULL DEFAULT '0', patch_max integer NOT NULL DEFAULT '10');
CREATE TABLE conditions (
  condition_entry integer NOT NULL PRIMARY KEY, type integer NOT NULL DEFAULT '0',
  value1 integer NOT NULL DEFAULT '0', value2 integer NOT NULL DEFAULT '0', value3 integer NOT NULL DEFAULT '0',
  value4 integer NOT NULL DEFAULT '0', flags integer NOT NULL DEFAULT '0');
CREATE TABLE game_event (
  entry integer NOT NULL PRIMARY KEY, start_time timestamp NOT NULL, end_time timestamp NOT NULL,
  occurence integer NOT NULL, length integer NOT NULL, holiday integer NOT NULL DEFAULT '0',
  description varchar(255) DEFAULT NULL, patch_min integer NOT NULL DEFAULT '0',
  patch_max integer NOT NULL DEFAULT '10');
CREATE TABLE gameobject_template (
  entry integer NOT NULL, patch integer NOT NULL DEFAULT '0', type integer NOT NULL DEFAULT '0',
  name varchar(100) NOT NULL DEFAULT '', data1 integer NOT NULL DEFAULT '0', PRIMARY KEY (entry, patch));
CREATE TABLE gameobject (
  guid integer NOT NULL PRIMARY KEY, id integer NOT NULL, patch_min integer NOT NULL DEFAULT '0',
  patch_max integer NOT NULL DEFAULT '10');
CREATE TABLE game_event_gameobject (guid integer NOT NULL, event integer NOT NULL, PRIMARY KEY (guid, event));
CREATE TABLE skill_fishing_base_level (entry integer NOT NULL PRIMARY KEY, skill integer NOT NULL DEFAULT '0');
"""

Row = dict[str, object]


def build(path: Path, tables: dict[str, Sequence[Row]]) -> Path:
    """Writes a database at path holding every table of the schema, with the given rows."""
    db = sqlite3.connect(path)
    try:
        db.executescript(_SCHEMA)
        for table, rows in tables.items():
            for row in rows:
                columns = ", ".join(row)
                marks = ", ".join("?" for _ in row)
                db.execute(f"INSERT INTO {table} ({columns}) VALUES ({marks})", tuple(row.values()))
        db.commit()
    finally:
        db.close()
    return path
