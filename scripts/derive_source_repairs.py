#!/usr/bin/env python3
"""Derive the source-repair tables of the Tsakhur dictionary (run once per upstream pin).

The v0 Tsakhur data (keyboard_data_v0.zip, tkr_*) is one word list: the
Tsakhur list of the Intercontinental Dictionary Series (IDS, list 70,
M. Khalilov). This script reads the 1,440 IDS rows that v0 read, replays the
v0 reading to prove that they are the same data, reads them again the way
they are written, and writes what differs to scripts/data/:

    ids_repaired_forms.tsv   every IDS form the two readings disagree on
    ids_restored_words.tsv   words the form contains that v0 does not have
    v0_cut_pieces.tsv        v0 rows that are pieces of such forms and nothing else
    ids_excluded_forms.tsv   forms set aside (a macron the alphabet has no letter for)
    ids_phrase_pairs.tsv     neighbouring words inside the multiword IDS forms

What went wrong in v0 (build_kb_data.py, lex_ids): the tokenizer ran on the
raw `Form` column, and

  * IDS stores «й» decomposed, as «и» + U+0306 COMBINING BREVE (239 forms).
    The token pattern knows Cyrillic letters only, so «кьадалий» became
    «кьадалии» and «айгъыр» became «аи» and «гъыр»;
  * IDS marks a palatalized consonant with ʼ U+02BC («голʼ», «колʼга»,
    67 words). The pattern stopped there: «гол», and «кол» + «га»;
  * four forms carry a macron («да̄к», «сӣмишаас»), cut the same way;
  * one word ends in a Latin «c» («гьачІиеъаc», twice), which cut it too.

The palochka was not damaged: IDS types it as І U+0406, which is inside the
Cyrillic block and which v0 then turned into ӏ.

Usage, from the repository root:

    python3 -I scripts/derive_source_repairs.py

Python 3 standard library only. The inputs are pinned by SHA-256; the output
is deterministic, and scripts/build_dictionary.py pins it in turn.
"""

import csv
import hashlib
import os
import re
import sys
import unicodedata
from collections import Counter, defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V0_WORDS = os.path.join(REPO, "dictionary-source", "original-v0", "tkr_words.tsv")
IDS_FORMS = os.path.join(REPO, "dictionary-source", "upstream", "ids-bf6c9f8", "forms_tsakhur_70.csv")
DATA = os.path.join(REPO, "scripts", "data")

# github.com/intercontinental-dictionary-series/ids at
# bf6c9f8c7d25c15e61e338f3ed29ae46b844c0f8 (2026-10-09), cldf/forms.csv, the
# rows with Language_ID 70, copied byte for byte.
PINNED = {
    V0_WORDS: "4f30f4510faa0337b31952831aa02bbf6079c73cdbb462647cf82871e1f4c625",
    IDS_FORMS: "e3c3a6701f90eda728ea23820469caaf0bb25cbc131cc7d41e6e30130cb161f1",
}

PALOCHKA = "ӏ"   # U+04CF, the lookup form
MARK = "ʼ"       # U+02BC MODIFIER LETTER APOSTROPHE, the palatalization mark
BREVE = "̆"
MACRON = "̄"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


# ----------------------------------------------------------------- the v0 reading
# build_kb_data.py, verbatim in what matters: TOKEN_RE on the raw form, then
# normalize_token and valid_token.
_CYR = "Ѐ-ӿ"
_V0_TOKEN = re.compile(rf"[{_CYR}]+(?:-[{_CYR}]+)*")
_V0_LOOKALIKES = {"I", "l", "i", "І", "і", "Ӏ", "1", "!", "|", "[", "]", "{", "}", "‡", "†"}
_V0_LATIN = {"a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х", "y": "у",
             "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н"}
_V0_ALPHABET = set("абвгдежзийклмнопрстуфхцчшщъыьэюяё") | {PALOCHKA}


def v0_reading(form):
    out = []
    for part in re.split(r"[;,/]", form):
        for tok in _V0_TOKEN.findall(part):
            tok = unicodedata.normalize("NFC", tok).strip().lower()
            tok = "".join(PALOCHKA if ch in _V0_LOOKALIKES else ch for ch in tok)
            tok = unicodedata.normalize("NFC", "".join(_V0_LATIN.get(ch, ch) for ch in tok))
            letters = sum(0 if ch in (PALOCHKA, "ь", "ъ", "-") else 1 for ch in tok)
            if (tok and len(tok) <= 40 and not tok.startswith("-") and not tok.endswith("-")
                    and "--" not in tok and letters >= 2
                    and all(ch in _V0_ALPHABET or ch == "-" for ch in tok)):
                out.append(tok)
    return out


# ----------------------------------------------------------------- the repaired reading
_WORD = rf"[а-яё{PALOCHKA}]+(?:{MARK}[а-яё{PALOCHKA}]*)*"
TOKEN = re.compile(rf"{_WORD}(?:-{_WORD})*")
TAILS = {PALOCHKA, "ь", "ъ", MARK}   # TsakhurDefinition.normalization.digraphTails


def letter_count(token):
    return sum(0 if ch in TAILS or ch == "-" else 1 for ch in token)


def repaired_reading(form):
    """(tokens, causes, excluded reason or None). Tokens keep their order;
    a token of fewer than two letters stays in the list as None so that the
    words on its two sides are not taken for neighbours."""
    causes = []
    if BREVE in form:
        causes.append("й")
    text = unicodedata.normalize("NFC", form).lower()
    text = re.sub("[ІіӀ]", PALOCHKA, text)
    if "ʼ" in text or "’" in text:
        causes.append(MARK)
        text = text.replace("’", MARK)
    if MACRON in text or "ӣ" in text:
        return [], causes + ["macron"], "a long vowel written with a macron"
    if re.search(r"[а-яё]c|c[а-яё]", text):
        causes.append("Latin c")
        text = re.sub(r"(?<=[а-яё])c|c(?=[а-яё])", "с", text)
    if re.search(r"[a-z]", text):
        raise SystemExit(f"unexpected Latin letter in {form!r}")
    tokens = [t if letter_count(t) >= 2 else None for t in TOKEN.findall(text)]
    leftover = TOKEN.sub("", text).strip()
    if leftover:
        raise SystemExit(f"unread characters {leftover!r} in {form!r}")
    return tokens, causes, None


def write(name, header, rows):
    path = os.path.join(DATA, name)
    with open(path, "w", encoding="utf-8", newline="") as f:
        wr = csv.writer(f, delimiter="\t", lineterminator="\n")
        wr.writerow(header)
        wr.writerows(rows)
    return path


def main():
    for path, digest in PINNED.items():
        if sha256(path) != digest:
            print(f"error: {os.path.relpath(path, REPO)} is not the pinned file "
                  f"(sha256 {sha256(path)})", file=sys.stderr)
            return 2

    with open(V0_WORDS, encoding="utf-8", newline="") as f:
        v0 = {r["word"] for r in csv.DictReader(f, delimiter="\t")}
    with open(IDS_FORMS, encoding="utf-8", newline="") as f:
        rows = [r for r in csv.DictReader(f)]
    if {r["Language_ID"] for r in rows} != {"70"}:
        raise SystemExit("the IDS extract holds rows of another list")

    replay = set()
    for r in rows:
        replay.update(v0_reading(r["Form"]))
    if replay != v0:
        raise SystemExit(f"replaying v0 on the IDS rows gives {len(replay)} words, v0 has {len(v0)}: "
                         "this is not the data v0 read")

    whole = Counter()                 # word -> IDS rows it stands in
    where = defaultdict(list)         # word -> IDS row ids
    cause_of = defaultdict(set)
    pairs = Counter()
    pair_ids = defaultdict(list)
    piece_from = defaultdict(list)    # v0 token -> rows whose repaired reading does not have it
    repaired, excluded = [], []
    for r in rows:
        old = v0_reading(r["Form"])
        tokens, causes, reason = repaired_reading(r["Form"])
        shown = unicodedata.normalize("NFC", r["Form"])
        if reason:
            excluded.append((r["ID"], shown, r["AlternativeValues"], reason, " ".join(old)))
        words = [t for t in tokens if t]
        for t in set(words):
            whole[t] += 1
            where[t].append(r["ID"])
            cause_of[t].update(causes)
        for a, b in zip(tokens, tokens[1:]):
            if a and b:
                pairs[(a, b)] += 1
                pair_ids[(a, b)].append(r["ID"])
        if sorted(old) != sorted(words):
            if not causes:
                raise SystemExit(f"{r['ID']} {shown!r}: the readings differ for no known cause")
            repaired.append((r["ID"], shown, r["AlternativeValues"], " + ".join(causes),
                             " ".join(old), " ".join(words)))
            for t in old:
                if t not in words:
                    piece_from[t].append(r["ID"])

    restored = sorted(set(whole) - v0)
    pieces = sorted(v0 - set(whole))
    for w in restored:
        if not cause_of[w]:
            raise SystemExit(f"{w!r} is new but stands in no repaired form")
    for w in pieces:
        if not piece_from[w]:
            raise SystemExit(f"{w!r} is a v0 row with no IDS form behind it")

    os.makedirs(DATA, exist_ok=True)
    written = [
        write("ids_repaired_forms.tsv", ["ids_id", "form", "transcription", "cause", "v0_reading", "reading"],
              repaired),
        write("ids_restored_words.tsv", ["word", "ids_rows", "ids_ids", "cause"],
              [(w, whole[w], " ".join(where[w]), " + ".join(c for c in ("й", MARK, "Latin c") if c in cause_of[w]))
               for w in restored]),
        write("v0_cut_pieces.tsv", ["piece", "ids_ids"], [(w, " ".join(piece_from[w])) for w in pieces]),
        write("ids_excluded_forms.tsv", ["ids_id", "form", "transcription", "reason", "v0_reading"], excluded),
        write("ids_phrase_pairs.tsv", ["prev", "word", "ids_rows", "ids_ids"],
              [(a, b, n, " ".join(pair_ids[(a, b)])) for (a, b), n in sorted(pairs.items())]),
    ]
    print(f"IDS rows {len(rows)}; v0 words {len(v0)} (replayed exactly)")
    print(f"forms read differently {len(repaired)}; set aside {len(excluded)}")
    print(f"words kept {len(v0 & set(whole))}; restored {len(restored)}; pieces {len(pieces)}; "
          f"words in all {len(whole)}")
    print(f"phrase pairs {len(pairs)} (weight total {sum(pairs.values())})")
    for path in written:
        print(f'    "{os.path.basename(path)}": "{sha256(path)}",')
    return 0


if __name__ == "__main__":
    sys.exit(main())
