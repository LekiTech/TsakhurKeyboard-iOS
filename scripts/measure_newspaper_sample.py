#!/usr/bin/env python3
"""Measure the letters of literary Tsakhur in a sample of the newspaper «Нур».

The keyboard's dictionary is a word list without frequencies, so it cannot
say how often a letter is typed. The only Tsakhur newspaper, «Нур»
(Makhachkala, since 1995), publishes its Tsakhur pages at
https://nur-05.ru/archives/nationals/ . This script reads a sample of them
and writes letter and digraph counts, nothing else, to
docs/layout/nur_sample.json, which scripts/analyze_layout.py and
docs/LAYOUT.md use. The articles themselves are not kept in the repository
and are not a source of the dictionary.

    python3 -I scripts/measure_newspaper_sample.py --fetch 4 --cache build/research/nur/sample
    python3 -I scripts/measure_newspaper_sample.py --cache build/research/nur/sample

--fetch N downloads the first N pages of the archive list (network) into the
cache folder; without it the cached texts are measured again. The archive
grows, so a later fetch gives another sample; the committed JSON records the
articles it was measured from (address, title, SHA-256 of the text).

Python 3 standard library only.
"""

import argparse
import hashlib
import html
import json
import os
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "docs", "layout", "nur_sample.json")
SITE = "https://nur-05.ru"
PALOCHKA = "ӏ"
MARK = "ʼ"
CYR = "А-Яа-яЁё"
_WORD = rf"[а-яё{PALOCHKA}]+(?:{MARK}[а-яё{PALOCHKA}]*)*"
TOKEN = re.compile(rf"{_WORD}(?:-{_WORD})*")
DIGRAPHS = ["гъ", "гь", "г" + PALOCHKA, "къ", "кь", "к" + PALOCHKA, "хъ", "хь", "х" + PALOCHKA,
            "п" + PALOCHKA, "т" + PALOCHKA, "ц" + PALOCHKA, "ч" + PALOCHKA, "дж",
            "а" + PALOCHKA, "о" + PALOCHKA, "у" + PALOCHKA, "ы" + PALOCHKA, "е" + PALOCHKA, "и" + PALOCHKA,
            "аь", "оь", "уь", "л" + MARK]
SPELLINGS = {
    "йа (not before ӏ)": rf"йа(?!{PALOCHKA})", "йаӏ": f"йа{PALOCHKA}", "я": "я",
    "йу (not before ӏ)": rf"йу(?!{PALOCHKA})", "ю": "ю",
    "word-initial йе": r"\bйе", "word-initial е": r"\bе", "word-initial э": r"\bэ",
    "аа": "аа", "ее": "ее", "оо": "оо", "ии": "ии", "уу": "уу", "ыы": "ыы",
}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (keyboard-research)"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return r.read().decode("utf-8", "replace")


def plain(fragment):
    fragment = re.sub(r"(?s)<script.*?</script>|<style.*?</style>", "", fragment)
    fragment = re.sub(r"<br\s*/?>|</p>|</div>|</h\d>|</li>", "\n", fragment)
    return html.unescape(re.sub(r"<[^>]+>", "", fragment))


def fetch(pages, cache):
    os.makedirs(cache, exist_ok=True)
    manifest, seen = [], set()
    for p in range(1, pages + 1):
        listing = get(f"{SITE}/archives/nationals?page={p}")
        time.sleep(0.7)
        for href in re.findall(r'href="((?:https://nur-05\.ru)?/\?nationals=[^"]+)"', listing):
            slug = urllib.parse.unquote(html.unescape(href).split("?nationals=", 1)[1])
            if slug in seen:
                continue
            seen.add(slug)
            url = f"{SITE}/?nationals=" + urllib.parse.quote(slug, safe="")
            page = get(url)
            time.sleep(0.7)
            body = re.search(r'(?s)<div class="article-body content-body">(.*?)<div class="article-info-panel', page)
            title = re.search(r"<title>(.*?)</title>", page)
            name = "a%03d.txt" % len(manifest)
            title = html.unescape(title.group(1)).replace(" - Нур - Свет", "") if title else ""
            with open(os.path.join(cache, name), "w", encoding="utf-8") as f:
                f.write(title + "\n\n" + (plain(body.group(1)).strip() if body else "") + "\n")
            manifest.append({"file": name, "url": url, "title": title})
    with open(os.path.join(cache, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)


def normalize(text):
    """Lowercase Tsakhur text with ӏ for every typed palochka and ʼ for every typed mark."""
    text = unicodedata.normalize("NFC", text).replace("­", "")
    # the palochka is typed as a Latin I (3,600 times), l, the Ukrainian І or,
    # between two letters, the digit 1
    text = re.sub(rf"(?<=[{CYR}])[IlІӀ]", PALOCHKA, text)
    text = re.sub(rf"(?<=[{CYR}])1(?=[{CYR}])", PALOCHKA, text)
    # the palatalization mark is typed as ' or ’ after a letter
    text = re.sub(rf"(?<=[{CYR}{PALOCHKA}])['’ʼ]", MARK, text)
    return text.lower()


def measure(cache):
    with open(os.path.join(cache, "manifest.json"), encoding="utf-8") as f:
        manifest = json.load(f)
    articles, texts, seen = [], [], set()
    typed = Counter()
    for a in manifest:
        with open(os.path.join(cache, a["file"]), encoding="utf-8") as f:
            raw = f.read()
        digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        body = raw.split("\n", 1)[1]
        key = hashlib.sha256(body.encode("utf-8")).hexdigest()
        tsakhur = len(re.findall(rf"[{CYR}][IlІӀ]|гь|хъ|къ|кь|гъ", raw))
        if key in seen or tsakhur < 20:      # the same article twice, or an article in Russian
            continue
        seen.add(key)
        typed.update(re.findall(rf"(?<=[{CYR}])[IlІӀ]", raw))
        typed.update(re.findall(rf"(?<=[{CYR}IӀ])['’ʼ]", raw))
        texts.append(raw)
        articles.append({"url": a["url"], "title": a["title"], "text_sha256": digest})
    words = TOKEN.findall(normalize("\n".join(texts)))
    joined = " ".join(words)
    letters = Counter(joined.replace(" ", ""))
    after_mark = Counter(m for m in re.findall(f"(.){MARK}", joined))
    before_palochka = Counter(m for m in re.findall(f"(.){PALOCHKA}", joined))
    marked = [w for w in words if MARK in w]
    return {
        "source": "the Tsakhur pages of the newspaper «Нур», https://nur-05.ru/archives/nationals/",
        "note": "letter statistics only; the articles are not a source of the dictionary",
        "articles": articles,
        "words": len(words),
        "distinct_words": len(set(words)),
        "letters": dict(sorted(letters.items(), key=lambda kv: (-kv[1], kv[0]))),
        "digraphs": {d: len(re.findall(d, joined)) for d in DIGRAPHS},
        "letter_before_palochka": dict(before_palochka.most_common()),
        "letter_before_mark": dict(after_mark.most_common()),
        "words_with_mark": len(marked),
        "words_ending_in_mark": sum(1 for w in marked if w.endswith(MARK)),
        "how_the_palochka_is_typed": {f"U+{ord(c):04X}": n for c, n in typed.most_common() if c in "IlІӀ"},
        "how_the_mark_is_typed": {f"U+{ord(c):04X}": n for c, n in typed.most_common() if c in "'’ʼ"},
        "spellings": {k: len(re.findall(p, joined)) for k, p in SPELLINGS.items()},
        "examples": {w: words.count(w) for w in ("йигъылʼ", "мизʼ", "миз", "хьян", "хʼян", "едʼ", "хылʼ", "дюнйе")},
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", required=True, help="folder of the fetched article texts")
    ap.add_argument("--fetch", type=int, metavar="N", help="download the first N pages of the archive list")
    args = ap.parse_args()
    if args.fetch:
        fetch(args.fetch, args.cache)
    result = measure(args.cache)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=1)
        f.write("\n")
    total = sum(result["letters"].values())
    print(f"{len(result['articles'])} articles, {result['words']} words, {total} letters")
    print(" ".join(f"{c}:{100 * n / total:.2f}" for c, n in result["letters"].items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
