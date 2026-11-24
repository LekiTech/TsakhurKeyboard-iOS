#!/usr/bin/env python3
"""Letter statistics of Tsakhur and a model comparison of layout candidates.

Python 3 standard library only. Reads

  * docs/layout/nur_sample.json: letter counts of 42 Tsakhur articles of the
    newspaper «Нур» (scripts/measure_newspaper_sample.py), the only measure
    of how often a letter is TYPED;
  * the shipped words artifact (TsakhurKeyboardExtension/tsakhur_words.sqlite),
    a word list without frequencies: every word counts once. It gives the
    word shapes for the thumb-travel model and a second, independent letter
    count.

Writes docs/layout/analysis.json and prints the same numbers.

    python3 -I scripts/analyze_layout.py

Everything here is a MODEL of typing, not a measurement of people:

  * a word is typed letter by letter, no suggestion is picked;
  * a letter with its own key costs one tap; a letter without one costs one
    long press on its base key;
  * time = taps × t + long presses × (t + delay), with the keyboard's default
    long-press delay of 0.3 s and a tap rate t of 0.25 s;
  * two thumbs: a key belongs to the thumb of its half of the keyboard, and a
    thumb travels in a straight line from the previous key it pressed in the
    same word. Key centres are those of General Keyboard's native grid on a
    402 pt wide iPhone (content width 395 pt, row pitch 54 pt); the third
    row is taken as the middle nine cells of an eleven-cell row.
"""

import json
import os
import sqlite3
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORDS = os.path.join(REPO, "TsakhurKeyboard", "TsakhurKeyboardExtension", "tsakhur_words.sqlite")
SAMPLE = os.path.join(REPO, "docs", "layout", "nur_sample.json")
OUT = os.path.join(REPO, "docs", "layout", "analysis.json")

P = "ӏ"   # ӏ U+04CF, the palochka of the dictionary rows (the key shows Ӏ U+04C0)
M = "ʼ"   # ʼ U+02BC, the palatalization mark
# The seventeen two-character letters of the alphabet of 1990.
DIGRAPHS = ["а" + P, "гъ", "гь", "г" + P, "дж", "къ", "кь", "к" + P, "о" + P, "п" + P, "т" + P,
            "у" + P, "хъ", "хь", "ц" + P, "ч" + P, "ы" + P]
SCREEN, SMALL_SCREEN = 402.0, 375.0
PAD, INSET, PITCH = 3.5, 3.0, 54.0
LONG_PRESS_DELAY = 0.3    # s, KeyboardSettings.CalloutDelay.normal
TAP = 0.25                # s

RUSSIAN = ["йцукенгшщзх", "фывапролджэ", "ячсмитьбю"]
CANDIDATES = {
    "A": {"title": "Russian iOS keyboard; ъ, Ӏ and ʼ under a long press on ь",
          "rows": RUSSIAN, "long": {"ъ": "ь", P: "ь", M: "ь", "ё": "е"}},
    "B": {"title": "ъ on щ's key, Ӏ on э's key; ʼ under ь (the layout shipped)",
          "rows": ["йцукенгшъзх", "фывапролдж" + P, "ячсмитьбю"],
          "long": {"щ": "ш", "э": P, "ё": "е", M: "ь"}},
    "B-ю": {"title": "ъ on щ's key, Ӏ on ю's key; ʼ under ь",
            "rows": ["йцукенгшъзх", "фывапролджэ", "ячсмитьб" + P],
            "long": {"щ": "ш", "ю": P, "ё": "е", M: "ь"}},
    "S": {"title": "ъ on щ's key, Ӏ on ы's key (Dargwa, Tabasaran, Aghul); ʼ under ь",
          "rows": ["йцукенгшъзх", "ф" + P + "вапролджэ", "ячсмитьбю"],
          "long": {"щ": "ш", "ы": P, "ё": "е", M: "ь"}},
    "L": {"title": "Ӏ on ы's key, ъ on э's key (Lak); ʼ under ь",
          "rows": ["йцукенгшщзх", "ф" + P + "вапролджъ", "ячсмитьбю"],
          "long": {"ы": P, "э": "ъ", "ё": "е", M: "ь"}},
    "C": {"title": "as B, and ʼ on ю's key",
          "rows": ["йцукенгшъзх", "фывапролдж" + P, "ячсмитьб" + M],
          "long": {"щ": "ш", "э": P, "ё": "е", "ю": "у"}},
    "D": {"title": "twelve keys in two rows: the Russian letters and ъ, Ӏ; ʼ under ь",
          "rows": ["йцукенгшщзхъ", "фывапролджэ" + P, "ячсмитьбю"],
          "long": {"ё": "е", M: "ь"}},
}
CHOSEN = "B"


def show(text):
    return text.replace(P, "Ӏ")


def key_width(row_length, screen):
    return round((screen - 2 * PAD) / row_length - 2 * INSET, 2)


def geometry(rows):
    """{letter: (x, y)} of the key centres on a 402 pt screen."""
    centres = {}
    width = SCREEN - 2 * PAD
    for r, row in enumerate(rows):
        cells = len(row) if r < 2 else len(rows[0])
        offset = 0 if r < 2 else (cells - len(row)) / 2
        for i, ch in enumerate(row):
            centres[ch] = (PAD + (i + offset + 0.5) * width / cells, r * PITCH)
    return centres


def evaluate(cand, sample, words):
    rows, long = cand["rows"], cand["long"]
    keyed = set("".join(rows))
    letters, n_words = sample["letters"], sample["words"]
    n_letters = sum(n for ch, n in letters.items() if ch != "-")
    missing = sorted(ch for ch in letters if ch != "-" and ch not in keyed)
    for ch in missing:
        if ch not in long:
            raise SystemExit(f"{ch!r} has neither a key nor a long press")
    presses = {ch: letters[ch] for ch in missing}
    lp = sum(presses.values())
    taps = n_letters - lp
    seconds = (taps * TAP + lp * (TAP + LONG_PRESS_DELAY)) / n_words * 100

    centres = geometry(rows)
    travel = same = moves = chars = 0
    need = lp_dict = 0
    for w in words:
        last = {}
        previous_side = None
        hit = False
        for ch in w:
            if ch == "-":
                continue
            base = ch if ch in keyed else long[ch]
            if ch not in keyed:
                lp_dict += 1
                hit = True
            x, y = centres[base]
            side = x < SCREEN / 2
            if side in last:
                px, py = last[side]
                travel += ((x - px) ** 2 + (y - py) ** 2) ** 0.5
            if previous_side is not None:
                moves += 1
                same += side == previous_side
            last[side] = (x, y)
            previous_side = side
            chars += 1
        need += hit
    return {
        "title": cand["title"],
        "rows": [show(r) for r in rows],
        "keys_per_row": [len(r) for r in rows],
        "narrowest_letter_key_pt": {"402 pt screen": key_width(max(len(r) for r in rows), SCREEN),
                                    "375 pt screen": key_width(max(len(r) for r in rows), SMALL_SCREEN)},
        "letters_moved_from_the_russian_layout":
            sorted(show(ch) for r, ru in zip(rows, RUSSIAN) for ch in r if ch not in ru) if len(rows[0]) == 11 else
            sorted(show(ch) for ch in keyed - set("".join(RUSSIAN))),
        "letters_without_a_key": [show(ch) for ch in missing],
        "newspaper_sample": {
            "long_presses_per_100_words": round(100 * lp / n_words, 2),
            "long_presses_per_100_letters": round(100 * lp / n_letters, 2),
            "by_letter_per_100_words": {show(ch): round(100 * n / n_words, 2)
                                        for ch, n in sorted(presses.items(), key=lambda kv: -kv[1])},
            "seconds_per_100_words": round(seconds, 1),
        },
        "word_list": {
            "long_presses_per_100_words": round(100 * lp_dict / len(words), 2),
            "words_needing_a_long_press_percent": round(100 * need / len(words), 2),
            "thumb_travel_pt_per_letter": round(travel / chars, 2),
            "same_thumb_transitions_percent": round(100 * same / moves, 2),
        },
    }


def main():
    with open(SAMPLE, encoding="utf-8") as f:
        sample = json.load(f)
    con = sqlite3.connect(f"file:{WORDS}?mode=ro", uri=True)
    words = [w for (w,) in con.execute("SELECT word FROM words ORDER BY word")]
    con.close()

    n_words = sample["words"]
    letters = {ch: n for ch, n in sample["letters"].items() if ch != "-"}
    total = sum(letters.values())
    dict_letters = Counter("".join(words).replace("-", ""))
    dict_total = sum(dict_letters.values())
    joined = " ".join(words)
    statistics = {
        "newspaper_sample": {
            "articles": len(sample["articles"]), "words": n_words, "letters": total,
            "letters_per_word": round(total / n_words, 2),
            "letter_percent": {show(ch): round(100 * n / total, 2) for ch, n in letters.items()},
            "per_100_words": {show(ch): round(100 * letters.get(ch, 0) / n_words, 2)
                              for ch in ("ъ", P, M, "ы", "э", "ю", "щ", "ё", "ф", "ц", "п")},
            "digraphs_per_100_words": {show(d): round(100 * n / n_words, 2)
                                       for d, n in sorted(sample["digraphs"].items(), key=lambda kv: -kv[1])},
            "alphabet_digraphs_per_100_words": round(
                100 * sum(sample["digraphs"][d] for d in DIGRAPHS) / n_words, 1),
            "letter_before_palochka": {show(k): v for k, v in sample["letter_before_palochka"].items()},
            "letter_before_mark": {show(k): v for k, v in sample["letter_before_mark"].items()},
            "words_with_mark_percent": round(100 * sample["words_with_mark"] / n_words, 2),
            "doubled_vowels_per_100_words": {k: round(100 * sample["spellings"][k] / n_words, 2)
                                             for k in ("аа", "ее", "оо", "ии")},
        },
        "word_list": {
            "words": len(words), "letters": dict_total,
            "note": "1,355 dictionary forms of the IDS list, each counted once: infinitives and "
                    "nouns in the citation form, so the shares differ from running text",
            "letter_percent": {show(ch): round(100 * n / dict_total, 2) for ch, n in dict_letters.most_common()},
            "digraph_words": {show(d): sum(1 for w in words if d in w) for d in DIGRAPHS},
            "words_with_mark": sum(1 for w in words if M in w),
            "words_with_palochka": sum(1 for w in words if P in w),
            "doubled_vowel_words": sum(1 for w in words if any(v * 2 in w for v in "аеиоуы")),
            "doubled_consonants": dict(Counter(a + b for a, b in zip(joined, joined[1:])
                                               if a == b and a in "бвгджзклмнпрстфхцчш").most_common()),
        },
    }
    report = {
        "sources": {"newspaper_sample": "docs/layout/nur_sample.json",
                    "word_list": "TsakhurKeyboard/TsakhurKeyboardExtension/tsakhur_words.sqlite"},
        "statistics": statistics,
        "model": {"long_press_delay_s": LONG_PRESS_DELAY, "tap_s": TAP, "screen_pt": SCREEN},
        "chosen": CHOSEN,
        "candidates": {name: evaluate(c, sample, words) for name, c in CANDIDATES.items()},
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
        f.write("\n")

    s = statistics["newspaper_sample"]
    print(f"newspaper sample: {s['articles']} articles, {s['words']} words, {s['letters_per_word']} letters per word")
    print("  per 100 words:", s["per_100_words"])
    print("  digraphs per 100 words:", s["digraphs_per_100_words"])
    print(f"{'':4}{'long presses / 100 words':>26}{'s / 100 words':>15}{'word list: lp / 100':>21}"
          f"{'travel pt':>11}{'narrowest key':>15}")
    for name, c in report["candidates"].items():
        print(f"{name:4}{c['newspaper_sample']['long_presses_per_100_words']:>26}"
              f"{c['newspaper_sample']['seconds_per_100_words']:>15}"
              f"{c['word_list']['long_presses_per_100_words']:>21}"
              f"{c['word_list']['thumb_travel_pt_per_letter']:>11}"
              f"{c['narrowest_letter_key_pt']['402 pt screen']:>15}   {c['title']}")
        print("      ", c["newspaper_sample"]["by_letter_per_100_words"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
