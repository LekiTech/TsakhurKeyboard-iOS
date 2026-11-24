#!/usr/bin/env python3
"""Build the Tsakhur keyboard dictionary from the v0 data (cleanup version 1).

Deterministic, Python 3 standard library only. Reads (never writes) the five
v0 Tsakhur files of keyboard_data_v0.zip, checked against pinned SHA-256 sums:

    tkr_words.sqlite  tkr_bigrams.sqlite  tkr_words.tsv  tkr_bigrams.tsv  tkr_stats.json

and the five source-repair tables of scripts/data/ (derived from the IDS rows
that v0 read by scripts/derive_source_repairs.py, also pinned).

Writes:

    <out>/tsakhur_words.sqlite      words(word, base_score) + meta   (General Keyboard artifact)
    <out>/tsakhur_bigrams.sqlite    bigrams(prev, word, weight) + meta
    <review>/manifest.json          the sources: archive, files, upstream commit, checksums, licence
    <review>/corrections.csv        every automatic change (rules R1 P1 X1 B1)
    <review>/merges.csv             every merge of a variant into another word (none in this version)
    <review>/flagged.csv            entries kept as they are and listed for a linguistic review
    <review>/high_priority.csv      the flagged entries to look at first
    <review>/reconciliation.csv     rows and weights of v0, of every rule and of the result
    <review>/summary.json           counts of the audit, the changes and the flags

Usage, from the repository root:

    python3 -I scripts/build_dictionary.py               # build + validate
    python3 -I scripts/build_dictionary.py --validate    # validate the shipped artifacts only
    python3 -I scripts/build_dictionary.py --source DIR --out DIR --review DIR

Set SOURCE_DATE_EPOCH to make meta.generated_at (and so the sqlite bytes)
reproducible; the rows are identical on every run regardless. The build
refuses to replace artifacts that carry a newer cleanup or content version
than this script (an obsolete checkout cannot overwrite approved data).

The rules are documented in docs/DICTIONARY.md. In short:

  * The Tsakhur data is one word list, the Tsakhur list of the
    Intercontinental Dictionary Series (IDS, list 70, M. Khalilov): 1,440
    typed forms, no running text, so no word has a frequency and v0 has no
    word pairs. It is not scanned. What is wrong with it came from how v0
    read the list, and every change names the IDS rows that show it:
      R1  words v0 cut, read whole: at a «й» that IDS stores as «и» + a
          combining breve («кьадалий», v0 «кьадалии»), at the palatalization
          mark ʼ («голʼ», «колʼга», v0 «гол», «кол» + «га»), at a Latin «c»
          typed for «с»;
      P1  the pieces those cuts left («аи», «гъыр» of «айгъыр»), which stand
          nowhere in the list as words: removed;
      X1  four forms with a macron («да̄к»), a length mark the alphabet has no
          letter for: set aside for a native speaker, their pieces removed;
      B1  the neighbouring words of the multiword IDS forms («кӏылʼна чодж»,
          younger brother) become word pairs, the weight being the number
          of IDS rows that have the pair. v0 has none.
  * Nothing is respelled into a form the list does not have, nothing is
    merged, and no frequency is made up: every word keeps the v0 score of a
    word-list entry (1). Doubtful spellings stay as they are and are
    written to flagged.csv.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SOURCE = os.path.join(REPO, "dictionary-source", "original-v0")
DEFAULT_OUT = os.path.join(REPO, "TsakhurKeyboard", "TsakhurKeyboardExtension")
DEFAULT_REVIEW = os.path.join(REPO, "docs", "dictionary", "review")
DATA = os.path.join(REPO, "scripts", "data")

# keyboard_data_v0.zip, folder keyboard_data/, built 2026-10-11. The v0
# language code is tkr (ISO 639-3).
ARCHIVE_SHA256 = "8cec9c22b314373386dbcbbbe1680d765b4f212de655162197af019402b8ac31"
V0_SHA256 = {
    "tkr_words.sqlite": "396d6a476c3305656425573f98c79cc0d2f86996f99dd3e157df3f00f3db76b8",
    "tkr_bigrams.sqlite": "a8b4bebc9b718f7d9ac13b877932541ebcd5945e03fdb025624c3c067fc82c55",
    "tkr_words.tsv": "4f30f4510faa0337b31952831aa02bbf6079c73cdbb462647cf82871e1f4c625",
    "tkr_bigrams.tsv": "964fc2a22e40d22aa4bdafe2ea8183c8c3285ac20dcc7f43d401b11ed87e6304",
    "tkr_stats.json": "50987f420baba93f40995725a61556377e1f67147e8ffc9dea225fa43896f148",
}
# scripts/data/, written by scripts/derive_source_repairs.py from the IDS rows.
REPAIR_SHA256 = {
    "ids_repaired_forms.tsv": "4fe7cb62688a3a790834b48f06b85e573a6fdc78b6e70d72645f0c8cd2b36c10",
    "ids_restored_words.tsv": "cdd1c900c7c51b5aa995d520f35c30cb1740ac8347f694cad07fe0f24df2c633",
    "v0_cut_pieces.tsv": "e821dbd29c07656a690619424aae2beb9c3c14f7c32b310e33974f7a8ed1b492",
    "ids_excluded_forms.tsv": "544f4e41ad6d01186285fca4e5c909718d1944c0e2a0be30312976cfcbbe7abd",
    "ids_phrase_pairs.tsv": "48b617eb18391ff1cc60c61fc20010d5fe16ad2480159a6451e0b64ad84b7f39",
}
# The IDS rows themselves (dictionary-source/upstream/ids-bf6c9f8/), which
# only derive_source_repairs.py reads.
UPSTREAM = {
    "repository": "https://github.com/intercontinental-dictionary-series/ids",
    "commit": "bf6c9f8c7d25c15e61e338f3ed29ae46b844c0f8",
    "commit_date": "2026-10-09",
    "file": "cldf/forms.csv",
    "file_sha256": "1ff6caa439d27d05c0ce7e72b656bfae5595bc5d12ae57b494e481e90e4e9968",
    "rows": "Language_ID 70 «Tsakhur» (author Madzhid Khalilov, data entry Stefan Lange), 1,440 rows",
    "extract": "dictionary-source/upstream/ids-bf6c9f8/forms_tsakhur_70.csv",
    "extract_sha256": "e3c3a6701f90eda728ea23820469caaf0bb25cbc131cc7d41e6e30130cb161f1",
    "licence": "CC BY 4.0",
    "citation": "Key, Mary Ritchie & Comrie, Bernard (eds.) 2023. The Intercontinental Dictionary Series. "
                "Leipzig: Max Planck Institute for Evolutionary Anthropology. https://ids.clld.org",
}

LANGUAGE = "tkr"
WORDS_ARTIFACT = "tsakhur_words"
BIGRAMS_ARTIFACT = "tsakhur_bigrams"
SCHEMA_VERSION = 1
CONTENT_VERSION = 1
NORMALIZATION_PROFILE = "tsakhur-cyrillic"   # TsakhurDefinition.swift, NormalizationProfile.id
NORMALIZATION_VERSION = 1
MIN_READER_SCHEMA = 1
CLEANUP_VERSION = 1

# The CREATE statements of the v0 files, which are the General Keyboard
# artifact shape (docs/engine/ARTIFACT_CONTRACT.md §1). The build checks that
# the v0 files carry exactly these and writes them unchanged.
WORDS_SQL = "CREATE TABLE words(word TEXT PRIMARY KEY, base_score INTEGER NOT NULL DEFAULT 0) WITHOUT ROWID"
BIGRAMS_SQL = ("CREATE TABLE bigrams(prev TEXT NOT NULL, word TEXT NOT NULL, weight INTEGER NOT NULL, "
               "PRIMARY KEY(prev, word)) WITHOUT ROWID")
META_SQL = "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)"

SOURCES = {
    "ids": "Intercontinental Dictionary Series, CLDF, list 70 «Tsakhur» (M. Khalilov), CC BY 4.0; "
           "word list, 1,440 forms; the only source of words",
    "ids_phrases": "the multiword forms of the same list; the only source of word pairs",
}

PALOCHKA = "ӏ"               # ӏ U+04CF, the lookup form (TextConventions shows Ӏ U+04C0)
MARK = "ʼ"                   # ʼ U+02BC MODIFIER LETTER APOSTROPHE, the palatalization mark
CONSONANTS = "бвгджзйклмнпрстфхцчшщ"
_WORD = rf"[а-яё{PALOCHKA}]+(?:{MARK}[а-яё{PALOCHKA}]*)*"
ALPHABET_RE = re.compile(rf"{_WORD}(?:-{_WORD})*")

# ----------------------------------------------------------------- the GK contract
# Mirror of GeneralKeyboard's Normalization.swift with the Tsakhur profile
# (TsakhurDefinition.normalization): the Dagestanian Cyrillic repairs, the
# other apostrophes read as the palatalization mark, and ӏ ь ъ ʼ as digraph
# tails. Used only to CHECK the rows.
_SWIFT_WHITESPACE = "\t\n\x0b\x0c\r\x85" + "".join(
    chr(cp) for cp in range(0x110000) if unicodedata.category(chr(cp)) in ("Zs", "Zl", "Zp"))
_LOOKALIKES = {"I", "l", "i", "І", "і", "Ӏ"}
_HOMOGLYPHS = {"a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х",
               "y": "у", "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н",
               "’": MARK, "‘": MARK, "`": MARK}
_TAILS = {PALOCHKA, "ь", "ъ", MARK}


def canonical(token):
    t = unicodedata.normalize("NFC", token).strip(_SWIFT_WHITESPACE).lower()
    if any(0x0400 <= ord(ch) <= 0x04FF for ch in t):
        t = "".join(PALOCHKA if ch in _LOOKALIKES else _HOMOGLYPHS.get(ch, ch) for ch in t)
    return unicodedata.normalize("NFC", t)


def letter_count(token):
    return sum(0 if ch in _TAILS else 1 for ch in token)


def is_valid_token(token):
    """Normalization.isValidToken for a canonical token."""
    if not token or len(token) > 64:
        return False
    if any(ch.isspace() or ch.isdigit() for ch in token) or any(ch in token for ch in "@/."):
        return False
    if any(ch.isascii() and ch.isalpha() for ch in token):
        return False
    if any(unicodedata.category(ch) in ("Cc", "Cf") for ch in token):
        return False
    return letter_count(token) >= 2


def is_tsakhur_token(token):
    """Canonical, storable, and written with а–я ё ӏ, the mark after a consonant, inner hyphens."""
    return (canonical(token) == token and is_valid_token(token) and bool(ALPHABET_RE.fullmatch(token))
            and not re.search(rf"(?<![{CONSONANTS}]){MARK}", token))


# ----------------------------------------------------------------- input
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def ro(path):
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def table_sql(con):
    return {name: sql for name, sql in con.execute("SELECT name, sql FROM sqlite_master WHERE type='table'")}


class Fail(Exception):
    pass


def load(source):
    for name, digest in V0_SHA256.items():
        path = os.path.join(source, name)
        if not os.path.exists(path):
            raise Fail(f"missing v0 file {path}")
        if sha256(path) != digest:
            raise Fail(f"{name}: SHA-256 differs from the pinned v0 file")

    wc, bc = ro(os.path.join(source, "tkr_words.sqlite")), ro(os.path.join(source, "tkr_bigrams.sqlite"))
    if table_sql(wc) != {"words": WORDS_SQL, "meta": META_SQL}:
        raise Fail("tkr_words.sqlite: unexpected schema")
    if table_sql(bc) != {"bigrams": BIGRAMS_SQL, "meta": META_SQL}:
        raise Fail("tkr_bigrams.sqlite: unexpected schema")
    sqlite_words = dict(wc.execute("SELECT word, base_score FROM words"))
    sqlite_pairs = {(a, b): w for a, b, w in bc.execute("SELECT prev, word, weight FROM bigrams")}
    v0_meta = dict(wc.execute("SELECT key, value FROM meta"))
    wc.close()
    bc.close()
    if v0_meta.get("language") != LANGUAGE:
        raise Fail(f"tkr_words.sqlite: meta.language is {v0_meta.get('language')!r}, expected {LANGUAGE!r}")

    words = {}
    with open(os.path.join(source, "tkr_words.tsv"), encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            words[r["word"]] = {
                "score": int(r["base_score"]), "count": int(r["count"]), "clean": int(r["clean_count"]),
                "ocr": int(r["ocr_count"]), "extra": int(r["extra_count"]), "lex": int(r["lexicon_sources"]),
            }
    if {w: r["score"] for w, r in words.items()} != sqlite_words:
        raise Fail("tkr_words.tsv and tkr_words.sqlite disagree")
    with open(os.path.join(source, "tkr_bigrams.tsv"), encoding="utf-8", newline="") as f:
        tsv_pairs = {(r["prev"], r["word"]): int(r["weight"]) for r in csv.DictReader(f, delimiter="\t")}
    if tsv_pairs != sqlite_pairs:
        raise Fail("tkr_bigrams.tsv and tkr_bigrams.sqlite disagree")
    with open(os.path.join(source, "tkr_stats.json"), encoding="utf-8") as f:
        stats = json.load(f)
    return words, sqlite_pairs, v0_meta, stats


def load_repairs():
    for name, digest in REPAIR_SHA256.items():
        path = os.path.join(DATA, name)
        if not os.path.exists(path):
            raise Fail(f"missing repair table {path}")
        if sha256(path) != digest:
            raise Fail(f"{name}: SHA-256 differs from the pinned table (re-run derive_source_repairs.py "
                       "only against the pinned IDS rows)")

    def rows(name):
        with open(os.path.join(DATA, name), encoding="utf-8", newline="") as f:
            return list(csv.DictReader(f, delimiter="\t"))

    return {
        "forms": rows("ids_repaired_forms.tsv"),
        "restored": [(r["word"], int(r["ids_rows"]), r["ids_ids"], r["cause"])
                     for r in rows("ids_restored_words.tsv")],
        "pieces": [(r["piece"], r["ids_ids"]) for r in rows("v0_cut_pieces.tsv")],
        "excluded": rows("ids_excluded_forms.tsv"),
        "pairs": [(r["prev"], r["word"], int(r["ids_rows"]), r["ids_ids"]) for r in rows("ids_phrase_pairs.tsv")],
    }


def v0_score(rec):
    """base_score of the v0 builder: 10 × corpus count + min(9, word lists)."""
    return 10 * rec["count"] + min(9, rec["lex"])


# ----------------------------------------------------------------- audit
def audit(words, pairs):
    inventory = Counter()
    for w in words:
        inventory.update(w)
    canon_groups = defaultdict(list)
    for w in words:
        canon_groups[canonical(w)].append(w)
    after = Counter()
    for w in words:
        for m in re.finditer(PALOCHKA, w):
            after[w[m.start() - 1] if m.start() else "^"] += 1
    return {
        "words": len(words),
        "bigrams": len(pairs),
        "character_inventory": {f"{ch} U+{ord(ch):04X}": n for ch, n in
                                sorted(inventory.items(), key=lambda kv: (-kv[1], kv[0]))},
        "palochka_after": dict(sorted(after.items(), key=lambda kv: (-kv[1], kv[0]))),
        "not_nfc": sorted(w for w in words if unicodedata.normalize("NFC", w) != w),
        "not_lowercase": sorted(w for w in words if w != w.lower()),
        "not_canonical": sorted(w for w in words if canonical(w) != w),
        "canonical_collisions": sorted(ws for ws in canon_groups.values() if len(ws) > 1),
        "contract_invalid": sorted(w for w in words if not is_valid_token(w)),
        "outside_alphabet": sorted(w for w in words if not ALPHABET_RE.fullmatch(w)),
        "latin_letters": sorted(w for w in words if any(ch.isascii() and ch.isalpha() for ch in w)),
        "visible_palochka_u04c0": sorted(w for w in words if "Ӏ" in w),
        "replacement_or_control_chars": sorted(
            w for w in words if any(ch == "�" or unicodedata.category(ch) in ("Cc", "Cf", "Co", "Cs")
                                    for ch in w)),
        "hyphenated": sorted(w for w in words if "-" in w),
        "with_palochka": sum(1 for w in words if PALOCHKA in w),
        "with_palatalization_mark": sum(1 for w in words if MARK in w),
        "with_short_i": sum(1 for w in words if "й" in w),
        "doubled_palochka": sorted(w for w in words if PALOCHKA * 2 in w),
        "same_letter_three_times": sorted(w for w in words if re.search(r"(.)\1\1", w)),
        "score_formula_mismatch": sorted(w for w, r in words.items() if r["score"] != v0_score(r)),
        "count_mismatch": sorted(w for w, r in words.items()
                                 if r["count"] != r["clean"] + r["ocr"] + r["extra"]),
        "words_with_a_frequency": sum(1 for r in words.values() if r["count"] > 0),
        "word_lists_only": sum(1 for r in words.values() if r["lex"] > 0 and r["count"] == 0),
        "bigram_orphans": sum(1 for a, b in pairs if a not in words or b not in words),
    }


# ----------------------------------------------------------------- changes
R1 = "R1 word of the IDS list that v0 cut, read whole"
P1 = "P1 piece left by a cut"
X1 = "X1 form with a macron, set aside"
B1 = "B1 word pair of a multiword IDS form"
CAUSES = {
    "й": "«й» stored as «и» + U+0306",
    MARK: "the palatalization mark ʼ",
    "Latin c": "a Latin «c» typed for «с»",
}


def apply_fixes(words, pairs, repairs):
    """final rows, final pairs and the log [(rule, action, entry, result, ids_rows, note)]."""
    final = {w: dict(r) for w, r in words.items()}
    log = []
    excluded_pieces = {t for r in repairs["excluded"] for t in r["v0_reading"].split()}

    for w, n, ids, cause in repairs["restored"]:
        if w in final:
            raise Fail(f"R1: {w!r} is a v0 row already")
        if not is_tsakhur_token(w):
            raise Fail(f"R1: {w!r} is not a canonical Tsakhur token")
        final[w] = {"score": 0, "count": 0, "clean": 0, "ocr": 0, "extra": 0, "lex": 1}
        log.append((R1, "row added", w, w, n,
                    "cut at " + " and at ".join(CAUSES[c] for c in cause.split(" + ")) + f"; IDS {ids}"))

    for w, ids in repairs["pieces"]:
        r = final.get(w)
        if r is None or r["count"] or r["lex"] != 1:
            raise Fail(f"P1: {w!r} is not a word-list-only v0 row")
        del final[w]
        rule = X1 if w in excluded_pieces and all(i in {x["ids_id"] for x in repairs["excluded"]}
                                                  for i in ids.split()) else P1
        log.append((rule, "row removed", w, "", len(ids.split()), f"IDS {ids}"))

    for r in repairs["excluded"]:
        log.append((X1, "form set aside", r["form"], "", 1,
                    f"{r['reason']}; IDS {r['ids_id']}, transcription {r['transcription']}"))

    final_pairs = dict(pairs)
    for a, b, n, ids in repairs["pairs"]:
        if a not in final or b not in final:
            raise Fail(f"B1: {a} {b}: a word of the pair is not a row")
        if (a, b) in final_pairs:
            raise Fail(f"B1: {a} {b} is a v0 pair already")
        final_pairs[(a, b)] = n
        log.append((B1, "pair added", f"{a} {b}", f"{a} {b}", n, f"IDS {ids}"))

    for r in final.values():
        r["score"] = v0_score(r)
    return final, final_pairs, log


# ----------------------------------------------------------------- flags
# The spelling checks compare the list with the literary usage of the
# newspaper «Нур» (a sample of 42 articles of 2026, 20,326 words, measured
# by scripts/measure_newspaper_sample.py into docs/layout/nur_sample.json).
# The sample is evidence for the notes, not an
# input of the build.
F_MARK = "written with the palatalization mark"
F_MARK_KH = "«хʼ» where the newspaper writes «хь»"
F_J_VOWEL = "«й» + vowel where the newspaper writes я, ю, е"
F_UMLAUT = "«аь» / «оь», not letters of the 1990 alphabet"
F_KH_PAL = "«хӏ», not a letter of the 1990 alphabet"
F_PHAR = "«еӏ» / «иӏ», not letters of the 1990 alphabet"
F_HYPHEN = "hyphenated entry"
F_LATIN = "typed with a Latin «c» in the source"
F_NAME = "a name: capitalized in the source"
F_EXCLUDED = "form with a macron, not in the dictionary"
HIGH = {F_MARK_KH, F_J_VOWEL, F_UMLAUT, F_KH_PAL, F_EXCLUDED}
# IDS writes these two with a capital (rows 70-22-120-1 and -2, "god").
NAMES = {"гӏыниш": "ГӀыниш", "аллагь": "Аллагь"}


def flag_entries(final, repairs):
    """Entries kept unchanged and listed for review: {word: [(category, note)]}."""
    flags = defaultdict(list)
    latin = {w for w, _, _, cause in repairs["restored"] if "Latin c" in cause}
    for w in final:
        if MARK in w:
            flags[w].append((F_MARK, "IDS marks a palatalized consonant with ʼ; «Нур» prints the same mark "
                                     "as ' or ’ («йигъыл'», «миз'»). The keyboard types ʼ (U+02BC)"))
        if "х" + MARK in w:
            flags[w].append((F_MARK_KH, "the list itself has «хьян» (water) in two other rows, and «Нур» has "
                                        "«хьян» 11 times in the sample and never «хʼян»"))
        if re.search(rf"йа(?!{PALOCHKA})|йу(?!{PALOCHKA})", w) or w.startswith("йе"):
            flags[w].append((F_J_VOWEL, "in the sample «я» stands 743 times and «йа» once (outside «йаӏ»), "
                                        "«ю» 241 times and «йу» never, a word begins with «е» 216 times and "
                                        "with «йе» once: the newspaper would write this word with я, ю or е"))
        if re.search("[аоу]ь", w):
            flags[w].append((F_UMLAUT, "the sample has no «аь», «оь» or «уь»"))
        if "х" + PALOCHKA in w:
            flags[w].append((F_KH_PAL, "the alphabet of 1990 has no «хӏ»; IDS writes ħ with it"))
        if re.search(f"[еи]{PALOCHKA}", w):
            flags[w].append((F_PHAR, "a pharyngealized «е» or «и»; the alphabet lists аӏ оӏ уӏ ыӏ only"))
        if "-" in w:
            flags[w].append((F_HYPHEN, "typed with a hyphen: the keyboard completes its halves as "
                                       "separate words"))
        if w in latin:
            flags[w].append((F_LATIN, "the last letter is a Latin «c» in IDS; read as «с» "
                                      "(the transcription has s)"))
        if w in NAMES:
            flags[w].append((F_NAME, f"IDS «{NAMES[w]}»; the dictionary keeps lowercase rows"))
    return flags


# ----------------------------------------------------------------- output
def generated_at():
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    t = datetime.fromtimestamp(int(epoch), timezone.utc) if epoch else datetime.now(timezone.utc)
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def guard_existing(out):
    """Refuse to replace artifacts built by a newer cleanup or content version."""
    for artifact_name in (WORDS_ARTIFACT, BIGRAMS_ARTIFACT):
        path = os.path.join(out, artifact_name + ".sqlite")
        if not os.path.exists(path):
            continue
        con = ro(path)
        try:
            meta = dict(con.execute("SELECT key, value FROM meta"))
        except sqlite3.Error:
            meta = {}
        finally:
            con.close()
        for key, ours in (("cleanup_version", CLEANUP_VERSION), ("content_version", CONTENT_VERSION),
                          ("schema_version", SCHEMA_VERSION)):
            theirs = meta.get(key)
            if theirs is not None and theirs.isdigit() and int(theirs) > ours:
                raise Fail(f"{path} has {key} {theirs}, newer than this script's {ours}: "
                           "refusing to overwrite it with older data")


def write_artifacts(out, final, pairs):
    os.makedirs(out, exist_ok=True)
    common = [
        ("schema_version", str(SCHEMA_VERSION)), ("content_version", str(CONTENT_VERSION)),
        ("normalization_version", str(NORMALIZATION_VERSION)), ("normalization_profile", NORMALIZATION_PROFILE),
        ("min_reader_schema", str(MIN_READER_SCHEMA)), ("cleanup_version", str(CLEANUP_VERSION)),
        ("generated_at", generated_at()), ("language", LANGUAGE),
        ("sources", json.dumps(SOURCES, ensure_ascii=False, sort_keys=True)),
    ]
    specs = [
        (WORDS_ARTIFACT, WORDS_SQL, "INSERT INTO words(word, base_score) VALUES(?, ?)",
         sorted((w, r["score"]) for w, r in final.items()),
         ["tkr_words.sqlite", "tkr_words.tsv", "ids_restored_words.tsv", "v0_cut_pieces.tsv",
          "ids_excluded_forms.tsv"]),
        (BIGRAMS_ARTIFACT, BIGRAMS_SQL, "INSERT INTO bigrams(prev, word, weight) VALUES(?, ?, ?)",
         sorted((a, b, v) for (a, b), v in pairs.items()),
         ["tkr_bigrams.sqlite", "tkr_bigrams.tsv", "ids_phrase_pairs.tsv"]),
    ]
    digests = {**V0_SHA256, **REPAIR_SHA256}
    for artifact_name, create, insert, rows, inputs in specs:
        path = os.path.join(out, artifact_name + ".sqlite")
        tmp = path + ".tmp"
        if os.path.exists(tmp):
            os.remove(tmp)
        con = sqlite3.connect(tmp)
        con.execute("PRAGMA page_size = 4096")
        con.execute(create)
        con.execute(META_SQL)
        con.executemany(insert, rows)
        derived = json.dumps({n: digests[n] for n in inputs}, sort_keys=True)
        meta = [("artifact", artifact_name)] + common + [("row_count", str(len(rows))), ("derived_from", derived)]
        con.executemany("INSERT INTO meta(key, value) VALUES(?, ?)", sorted(meta))
        con.commit()
        con.execute("VACUUM")
        con.close()
        os.replace(tmp, path)


FLAG_HEADER = ["priority", "status", "word", "base_score", "categories", "notes"]


def flag_rows(final, flags, repairs):
    rows = []
    for w, items in flags.items():
        prio = "high" if any(c in HIGH for c, _ in items) else "normal"
        rows.append([prio, "entry", w, final[w]["score"], "; ".join(c for c, _ in items),
                     "; ".join(n for _, n in items)])
    for r in repairs["excluded"]:
        rows.append(["high", "not an entry", r["form"], "", F_EXCLUDED,
                     f"IDS {r['ids_id']}, transcription {r['transcription']}: how is the long vowel written? "
                     "(v0 had the pieces «" + "», «".join(r["v0_reading"].split()) + "»)"])
    rows.sort(key=lambda row: (row[0] != "high", row[4], row[2]))
    return rows


def write_reviews(review, log, rows, reconciliation, manifest, summary):
    os.makedirs(review, exist_ok=True)

    def table(name, header, body):
        with open(os.path.join(review, name), "w", encoding="utf-8", newline="") as f:
            wr = csv.writer(f, lineterminator="\n")
            wr.writerow(header)
            wr.writerows(body)

    table("corrections.csv", ["rule", "action", "entry", "result", "ids_rows", "note"],
          sorted(log, key=lambda r: (r[0], r[1], r[2])))
    table("merges.csv", ["source", "target", "rule", "target_base_score_before", "target_base_score_after"], [])
    table("flagged.csv", FLAG_HEADER, rows)
    table("high_priority.csv", FLAG_HEADER, [r for r in rows if r[0] == "high"])
    table("reconciliation.csv", ["step", "words", "base_score_total", "bigrams", "bigram_weight_total"],
          reconciliation)
    for name, payload in (("manifest.json", manifest), ("summary.json", summary)):
        with open(os.path.join(review, name), "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=1, sort_keys=False)
            f.write("\n")


# ----------------------------------------------------------------- validation
# Pinned so that a rule change cannot slip through unnoticed.
EXPECTED_WORDS = 1355
EXPECTED_BIGRAMS = 134
EXPECTED_BIGRAM_WEIGHT = 137
EXPECTED_WITH_MARK = 67


def validate(out):
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok), detail))

    wp, bp = os.path.join(out, WORDS_ARTIFACT + ".sqlite"), os.path.join(out, BIGRAMS_ARTIFACT + ".sqlite")
    wc, bc = ro(wp), ro(bp)
    for con, table, artifact_name, create, expected in ((wc, "words", WORDS_ARTIFACT, WORDS_SQL, EXPECTED_WORDS),
                                                        (bc, "bigrams", BIGRAMS_ARTIFACT, BIGRAMS_SQL,
                                                         EXPECTED_BIGRAMS)):
        meta = dict(con.execute("SELECT key, value FROM meta"))
        n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        check(f"{artifact_name}: meta.artifact", meta.get("artifact") == artifact_name, meta.get("artifact"))
        check(f"{artifact_name}: meta.row_count == COUNT(*) ({n})", meta.get("row_count") == str(n),
              meta.get("row_count"))
        check(f"{artifact_name}: {expected} rows (cleanup version {CLEANUP_VERSION})", n == expected, str(n))
        for k, v in (("schema_version", SCHEMA_VERSION), ("content_version", CONTENT_VERSION),
                     ("normalization_version", NORMALIZATION_VERSION),
                     ("normalization_profile", NORMALIZATION_PROFILE), ("min_reader_schema", MIN_READER_SCHEMA),
                     ("cleanup_version", CLEANUP_VERSION), ("language", LANGUAGE)):
            check(f"{artifact_name}: meta.{k} == {v}", meta.get(k) == str(v), meta.get(k))
        for k in ("generated_at", "sources", "derived_from"):
            check(f"{artifact_name}: meta.{k} present", bool(meta.get(k)))
        check(f"{artifact_name}: schema is the General Keyboard artifact shape",
              table_sql(con) == {table: create, "meta": META_SQL})
        check(f"{artifact_name}: page_size 4096", con.execute("PRAGMA page_size").fetchone()[0] == 4096)
        check(f"{artifact_name}: vacuumed", con.execute("PRAGMA freelist_count").fetchone()[0] == 0)
        check(f"{artifact_name}: integrity_check", con.execute("PRAGMA integrity_check").fetchone()[0] == "ok")
    words = dict(wc.execute("SELECT word, base_score FROM words"))
    pairs = list(bc.execute("SELECT prev, word, weight FROM bigrams"))
    bad = [w for w in words if canonical(w) != w]
    check("every word is canonical under the Tsakhur profile", not bad, ", ".join(bad[:5]))
    bad = [w for w in words if not is_valid_token(w)]
    check("every word passes the token contract", not bad, ", ".join(bad[:5]))
    bad = [w for w in words if not is_tsakhur_token(w)]
    check("every word uses only а–я, ё, ӏ (U+04CF), ʼ (U+02BC) after a consonant and inner hyphens",
          not bad, ", ".join(bad[:5]))
    check("no visible palochka U+04C0 in lookup keys", not any("Ӏ" in w for w in words))
    check("no doubled palochka or mark", not any(PALOCHKA * 2 in w or MARK * 2 in w for w in words))
    check("no combining mark is left in a word", not any(unicodedata.combining(ch) for w in words for ch in w))
    n = sum(1 for w in words if MARK in w)
    check(f"{EXPECTED_WITH_MARK} words carry the palatalization mark", n == EXPECTED_WITH_MARK, str(n))
    for w in ("кьадалий", "айгъыр", "йигъ", "голʼ", "колʼга", "хылʼ", "гьачӏиеъас"):
        check(f"«{w}» is a row", w in words)
    for w in ("кьадалии", "аи", "гъыр", "игъ", "гол", "кол", "хыл", "гьачӏиеъа", "си", "мишаас"):
        check(f"the piece «{w}» is not a row", w not in words)
    check("every base_score is 1 (a word-list entry; the data has no frequencies)",
          all(s == 1 for s in words.values()))
    bad = [(a, b) for a, b, _ in pairs if a not in words or b not in words]
    check("both words of every pair are rows of the words artifact", not bad, str(bad[:3]))
    check("every pair weight >= 1", all(v >= 1 for _, _, v in pairs))
    total = sum(v for _, _, v in pairs)
    check(f"pair weights add up to {EXPECTED_BIGRAM_WEIGHT}", total == EXPECTED_BIGRAM_WEIGHT, str(total))
    wc.close()
    bc.close()
    return results


# ----------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=DEFAULT_SOURCE, help="folder with the five v0 tkr_* files")
    ap.add_argument("--out", default=DEFAULT_OUT, help="where the two artifacts are written")
    ap.add_argument("--review", default=DEFAULT_REVIEW, help="where the review files are written")
    ap.add_argument("--validate", action="store_true", help="only validate the artifacts in --out")
    args = ap.parse_args()

    def report(results):
        for name, ok, detail in results:
            print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""))
        return 0 if all(ok for _, ok, _ in results) else 1

    if args.validate:
        return report(validate(args.out))
    try:
        guard_existing(args.out)
        words, pairs, v0_meta, stats = load(args.source)
        repairs = load_repairs()
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    a = audit(words, pairs)
    hard = {k: a[k] for k in ("not_nfc", "not_lowercase", "not_canonical", "canonical_collisions",
                              "contract_invalid", "outside_alphabet", "latin_letters", "visible_palochka_u04c0",
                              "replacement_or_control_chars", "score_formula_mismatch", "count_mismatch")
            if a[k]}
    if hard or a["bigram_orphans"] or a["words_with_a_frequency"]:
        print("error: the v0 data breaks an assumption of this build:",
              json.dumps(hard, ensure_ascii=False)[:2000], file=sys.stderr)
        return 2

    try:
        final, final_pairs, log = apply_fixes(words, pairs, repairs)
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    flags = flag_entries(final, repairs)
    rows = flag_rows(final, flags, repairs)

    def totals(ws, ps):
        return [len(ws), sum(r["score"] for r in ws.values()), len(ps), sum(ps.values())]

    removed = {w: words[w] for w, _ in repairs["pieces"]}
    added = {w: final[w] for w, *_ in repairs["restored"]}
    reconciliation = [
        ["v0 (keyboard_data_v0.zip, tkr)"] + totals(words, pairs),
        ["P1 + X1: pieces of cut words removed", -len(removed), -sum(r["score"] for r in removed.values()), 0, 0],
        ["R1: words of the IDS list restored", len(added), sum(r["score"] for r in added.values()), 0, 0],
        ["B1: pairs of the multiword IDS forms", 0, 0, len(repairs["pairs"]), sum(n for _, _, n, _ in repairs["pairs"])],
        ["this dictionary"] + totals(final, final_pairs),
    ]
    for i in range(1, 5):
        if [sum(r[i] for r in reconciliation[:4])] != [reconciliation[4][i]]:
            print("error: the reconciliation does not add up", file=sys.stderr)
            return 2

    manifest = {
        "archive": {"file": "keyboard_data_v0.zip", "sha256": ARCHIVE_SHA256, "folder": "keyboard_data/",
                    "built": v0_meta.get("generated_at"), "language": LANGUAGE},
        "v0_files": V0_SHA256,
        "v0_sources": stats.get("sources"),
        "upstream": UPSTREAM,
        "repair_tables": REPAIR_SHA256,
        "not_used": {"ids_532": "IDS list 532 «Tsakhur (Gelmets dialect)», 1,381 forms: another dialect; "
                                "v0 did not read it and neither does this build",
                     "nur_newspaper": "the Tsakhur pages of the newspaper «Нур» (nur-05.ru): read as evidence "
                                      "of the literary spelling and for letter statistics only"},
    }
    by_rule = Counter((rule.split()[0], action) for rule, action, *_ in log)
    by_cat = Counter(c for items in flags.values() for c, _ in items)
    by_cause = Counter(cause for *_, cause in repairs["restored"])
    summary = {
        "input": {"v0_generated_at": v0_meta.get("generated_at"), "v0_sources": stats.get("sources"),
                  "ids_rows": 1440, "ids_forms_read_differently": len(repairs["forms"]),
                  "ids_forms_set_aside": len(repairs["excluded"])},
        "audit": a,
        "changes": {
            "by_rule_and_action": {f"{rule} {action}": n for (rule, action), n in sorted(by_rule.items())},
            "rows_removed": len(removed),
            "rows_added": len(added),
            "restored_by_cause": dict(sorted(by_cause.items(), key=lambda kv: -kv[1])),
            "pairs_added": len(repairs["pairs"]),
            "respelled": 0,
            "merged": 0,
        },
        "flags": {"listed": len(rows),
                  "entries": len(flags),
                  "forms_set_aside": len(repairs["excluded"]),
                  "high_priority": sum(1 for r in rows if r[0] == "high"),
                  "by_category": dict(sorted(by_cat.items(), key=lambda kv: (-kv[1], kv[0])))},
        "output": {"words": len(final), "bigrams": len(final_pairs),
                   "words_unchanged_from_v0": sum(1 for w, r in final.items() if words.get(w) == r),
                   "words_with_palochka": sum(1 for w in final if PALOCHKA in w),
                   "words_with_palatalization_mark": sum(1 for w in final if MARK in w),
                   "words_with_short_i": sum(1 for w in final if "й" in w),
                   "words_with_a_frequency": 0,
                   "base_score_total": sum(r["score"] for r in final.values()),
                   "base_score_total_v0": sum(r["score"] for r in words.values()),
                   "bigram_weight_total": sum(final_pairs.values()),
                   "bigram_weight_total_v0": sum(pairs.values())},
    }
    write_artifacts(args.out, final, final_pairs)
    write_reviews(args.review, log, rows, reconciliation, manifest, summary)
    results = validate(args.out)
    print(json.dumps({k: summary[k] for k in ("changes", "flags", "output")}, ensure_ascii=False, indent=1))
    return report(results)


if __name__ == "__main__":
    sys.exit(main())
