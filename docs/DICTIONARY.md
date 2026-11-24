# The Tsakhur dictionary

`tsakhur_words.sqlite` and `tsakhur_bigrams.sqlite`, the two files the
keyboard reads its suggestions from, cleanup version 1.

| | v0 | this dictionary |
|---|---|---|
| Words | 1,396 | **1,355** |
| Sum of `base_score` | 1,396 | 1,355 |
| Words with a frequency | 0 | 0 |
| Word pairs | 0 | **134** |
| Sum of pair weights | 0 | 137 |

**What this dictionary is, plainly.** It is small and it has no
frequencies. Its only source is one word list of dictionary forms
(nouns in the absolutive, verbs in the infinitive), so the keyboard
completes those forms and does not know which words are common or how
words are inflected. Of its 1,355 words, 211 occurred in a 20,326-word
sample of the newspaper «Нур» (measured once, on 2026-11-23). Most of
what a person types will not be in it until the keyboard has learned it
from them, which it does after three uses. A real improvement needs
running text: see [what would help](#what-would-help).

**It has not been reviewed by a Tsakhur speaker.**

## Source

`keyboard_data_v0.zip` (SHA-256 `8cec9c22b314373386dbcbbbe1680d765b4f212de655162197af019402b8ac31`,
folder `keyboard_data/`, built 2026-10-11) holds five Tsakhur files,
`tkr_words.tsv`, `tkr_words.sqlite`, `tkr_bigrams.tsv`,
`tkr_bigrams.sqlite` and `tkr_stats.json`. They are copied unchanged to
`dictionary-source/original-v0/` with their checksums; the archive itself
was only read.

v0 names one source for them, `ids`: the Tsakhur list of the
**Intercontinental Dictionary Series** (list 70, compiled by Madzhid
Khalilov, entered by Stefan Lange; Key & Comrie (eds.) 2023, CC BY 4.0).
The v0 notes say why there is nothing else: no Cyrillic Tsakhur text was
found in the sources v0 could reach. So v0 has

- 1,396 words, every one with `base_score` 1, the score of a word-list
  entry (`10 × corpus count + number of word lists`, with no corpus);
- no word pairs at all.

The list itself was fetched again for this build, to check v0 against it:
`cldf/forms.csv` of https://github.com/intercontinental-dictionary-series/ids
at commit `bf6c9f8c7d25c15e61e338f3ed29ae46b844c0f8` (2026-10-09). Its
1,440 rows with `Language_ID` 70 are in
`dictionary-source/upstream/ids-bf6c9f8/forms_tsakhur_70.csv`, byte for
byte. Running the v0 reader on those rows gives exactly the 1,396 words of
v0, so this is the data v0 read. `docs/dictionary/review/manifest.json`
lists every input with its checksum.

### How the list is written

The IDS forms are typed, not scanned: there is no OCR in this data. The
list writes Tsakhur in Cyrillic with a transcription beside each form.

| In the list | Meaning | In the dictionary |
|---|---|---|
| І U+0406 (Ukrainian І), 401 times | the palochka | ӏ U+04CF, the lookup form; the keyboard shows Ӏ U+04C0 |
| и + U+0306 (combining breve), in 239 forms | «й», stored decomposed | й U+0439 |
| ʼ U+02BC after a consonant, in 76 forms | a palatalized consonant: «голʼ» golʲ, «кокʼ» kokʲ | kept as ʼ U+02BC |
| a doubled vowel, in 63 forms | a long vowel: «аазыр» | kept |
| а̄, ӣ (a macron), in 4 forms | a long vowel, written another way | the form is set aside |
| a Latin «c» at the end of one word, twice | a typing slip for «с» (the transcription has s) | с |
| a space, in 139 forms | a phrase of two or more words | each word is an entry; neighbours are a pair |
| a capital, in 2 forms | a name: «ГІыниш», «Аллагь» (god) | lowercase rows |

No Latin «I» stands for the palochka anywhere in the list, so the kind of
damage found in the Aghul data (words cut at a Latin «I») is not here.
The damage is of another kind.

## What was wrong: the v0 reader cut 309 forms

The v0 builder (`build_kb_data.py`, function `lex_ids`) took the words
out of the raw `Form` column with a pattern that knows the letters of
the Cyrillic block and nothing else, and normalized each piece
afterwards. Three things in the list are not in that block:

- **The combining breve of «й».** The pattern stopped at it: «кьадалий»
  was read as «кьадалии», and a word with «й» in the middle fell apart,
  «айгъыр» into «аи» and «гъыр», «йигъ» (day) into «игъ». v0 has no word
  with «й» at all. 236 forms.
- **The palatalization mark.** «голʼ» became «гол», «колʼга» became
  «кол» and «га». 76 forms.
- **The macron**, in four forms, and **the Latin «c»**, in one word.

In all, 309 of the 1,440 forms were read wrongly, and 314 of the 1,396
v0 words (22 %) are pieces or misreadings that stand nowhere in the list
as words.

## What the build does

`scripts/derive_source_repairs.py` reads the IDS rows the way they are
written and writes what differs from v0 to `scripts/data/`;
`scripts/build_dictionary.py` applies those tables to the v0 files. Every
change names the IDS rows that show it (`docs/dictionary/review/corrections.csv`).

| Rule | What | Rows |
|---|---|---|
| **R1** | a word of the list that v0 cut, read whole | +273 words: 201 for «й», 58 for the mark, 13 for both, 1 for the Latin «c» |
| **P1** | a piece left by a cut, attested nowhere in the list as a word | −310 words |
| **X1** | the four forms with a macron are set aside, their pieces removed | −4 words |
| **B1** | neighbouring words inside the multiword forms become word pairs | +134 pairs |

Unchanged from v0: 1,082 words.

**R1.** «кьадалий», «айгъыр», «йигъ», «дюнйе», «балугъчий», «голʼ»,
«колʼга», «хылʼ», «кӀылʼна», «гьачӀиеъас» and 263 more. Each is a form
of the list or a word of one of its phrases, read after putting the text
into NFC, with the mark kept. Nothing was respelled: the word is in the
dictionary as the list writes it.

**P1.** «кьадалии», «аи», «гъыр», «игъ», «гол», «кол», «га», «хыл»…
A v0 word stays if the list has it as a word («хьян», «гьаъас»); it is
removed only if every occurrence of it is a piece of a longer word. Ten
of the removed pieces happen to be spelled like words seen in the
newspaper sample («на», «ма», «из», «ин», «бы», «ил», «не», «хьи»,
«чил», «карас»). They are removed all the same: the list does not have
them, and a dictionary entry should come from a source, not from an
accident of reading.

**X1.** «да̄к» (dāk), «урӣе» (urīye), «сӣмишаас» (sīmišaʔas),
«сӣмишхьес» (sīmišx̌es). The list writes a long vowel doubled in 63 forms
and with a macron in these four. Whether they are «даак», «уриие»… in
the literary spelling is not for this build to decide, so they are not
entries; they head `high_priority.csv`.

**B1.** The list has 139 multiword forms («кӀылʼна чодж», younger
brother; «кӀылʼна йичи», younger sister; «эва гьаъас»). Two words that
stand next to each other in such a form are a pair, with the number of
forms that have the pair as its weight (131 pairs once, 3 pairs twice).
v0 took no pairs from word lists; without these the keyboard would have
no next-word suggestion of its own at all. They are attested sequences,
not estimates, but a pair seen once is weak evidence, and the next word
will mostly come from what the user has typed. A pair across a
one-letter word («е», «и») is not made.

### Frequencies

Nothing was invented. Every word has the v0 score of a word-list entry,
1, and the reconciliation is exact (`docs/dictionary/review/reconciliation.csv`):

| Step | Words | Score total | Pairs | Weight total |
|---|---|---|---|---|
| v0 | 1,396 | 1,396 | 0 | 0 |
| P1 + X1: pieces removed | −314 | −314 | | |
| R1: words restored | +273 | +273 | | |
| B1: pairs of the multiword forms | | | +134 | +137 |
| this dictionary | 1,355 | 1,355 | 134 | 137 |

With equal scores the keyboard offers the shortest words that begin with
what was typed.

### Merges

None. `merges.csv` has a header and no rows.

## What was left alone, and flagged

`flagged.csv` lists 102 items: 98 entries kept exactly as the list has
them and the 4 forms set aside. `high_priority.csv` has the 28 to look at
first. No entry has a frequency, so "high priority" here means a spelling
that the literary usage of the newspaper «Нур» contradicts or that the
alphabet of 1990 does not provide for.

| Category | Entries | Priority | Evidence |
|---|---|---|---|
| a form with a macron, not in the dictionary | 4 | high | above |
| «й» + vowel where the newspaper writes я, ю, е | 17 | high | in the sample «я» stands 743 times and «йа» once outside «йаӀ», «ю» 241 times and «йу» never; a word begins with «е» 216 times and with «йе» once. The list has «йакорь», «йубка», «шлйапа», «йавашда», «гьайат»… |
| «хӀ» | 5 | high | not a letter of the alphabet; the list writes ħ with it («кухӀ», «хӀинака») |
| «аь», «оь» | 3 | high | not letters of the alphabet; none in the sample («оьца», «маьхӀли», «аьцайаънас») |
| «хʼ» where the list and the newspaper have «хь» | 1 | high | «хʼян» in one phrase; the list has «хьян» (water) in two other rows and the newspaper 11 times |
| written with the palatalization mark | 67 | normal | the mark is literary usage («йигъыл'», «миз'» in «Нур»); the question is its code point, `docs/LAYOUT.md` |
| hyphenated entry | 4 | normal | «цык-цык», «тӀянкӀ-тӀянкӀ», «са-кьолле», «экӀда-экӀда»; the keyboard completes the halves as separate words |
| «еӀ», «иӀ» | 3 | normal | pharyngealized «е», «и»; the alphabet lists аӀ оӀ уӀ ыӀ only |
| a name, capitalized in the list | 2 | normal | «гӀыниш», «аллагь» are lowercase rows |
| typed with a Latin «c» in the list | 1 | normal | «гьачӀиеъас» |

None of these was respelled, merged or removed. The cautions that the
Tabasaran cleanup taught apply here in full: a spelling is not replaced
by a more frequent one, and the list's way of writing a word may be a
dialect form or its author's considered choice.

## Questions for Tsakhur speakers

1. The four forms with a macron: «да̄к», «урӣе», «сӣмишаас»,
   «сӣмишхьес». How are they spelled?
2. The 17 words with «йа», «йу», «йе» («йакорь», «йубка», «шлйапа»,
   «йавашда», «дерйагь»…): does the literary spelling write «якорь»,
   «юбка», «шляпа», «явашда», «дерягь»? If so they should be respelled,
   word by word, by someone who knows them.
3. «хӀ», «аь», «оь», «еӀ», «иӀ»: are these words written so in print,
   or with other letters?
4. «хʼян» and «хьян»: one word, and is «хьян» its spelling?
5. «миз» is in the list without the mark, and the newspaper prints both
   «миз» and «миз'». Which is the spelling of the word for "language"?
6. The palatalization mark in general: the list marks it in 67 words.
   Are there words where the literary spelling leaves it out, or writes
   «ь»?
7. The list is of the dialect its author recorded (IDS calls it
   «Tsakhur»; a second IDS list is «Gelmets dialect»). Are its words
   those of the literary language?

## What would help

- **Running text.** The newspaper «Нур» publishes its Tsakhur pages
  online (https://nur-05.ru/archives/nationals/, 114 list pages on
  2026-11-23). A corpus built from them, with the publisher's consent,
  would give real word frequencies, inflected forms and word pairs. It
  was used here only as evidence of the spelling and for letter counts
  (`docs/LAYOUT.md`): adding a new source to the dictionary is the
  owner's decision, and the articles belong to the newspaper.
- **The Tsakhur–Russian dictionary** of Ibragimov and Nurmamedov
  (Makhachkala, 2010), the reference for literary spelling, to check the
  flagged entries against.
- **The second IDS list**, «Tsakhur (Gelmets dialect)» (list 532, 1,381
  forms): another dialect, not read by v0 and not read here.

## Schema and checks

The artifacts have the General Keyboard shape of v0, unchanged:
`words(word TEXT PRIMARY KEY, base_score INTEGER NOT NULL DEFAULT 0)
WITHOUT ROWID`, `bigrams(prev, word, weight, PRIMARY KEY(prev, word))
WITHOUT ROWID`, and `meta(key, value)` in each. No column was added.
`meta` records `language` tkr, `normalization_profile` tsakhur-cyrillic
(the profile of `TsakhurDefinition.swift`, which the build script
mirrors), `cleanup_version` 1, the sources and the checksums of the
inputs.

Every word is lowercase, NFC, canonical under the keyboard's profile
(palochka ӏ U+04CF, mark ʼ U+02BC after a consonant), at least two
letters long, and written with а–я, ё, ӏ, ʼ and inner hyphens only; both
words of every pair are words of the dictionary. The build checks this
(62 checks) and the tests check the shipped files again
(`Tests/TsakhurCoreTests/DictionaryTests.swift`).

## Rebuilding

```bash
python3 -I scripts/derive_source_repairs.py                            # scripts/data/*.tsv from the IDS rows
SOURCE_DATE_EPOCH=1795392000 python3 -I scripts/build_dictionary.py    # the two artifacts and docs/dictionary/review/
python3 -I scripts/build_dictionary.py --validate                      # check the shipped artifacts only
```

Python 3, standard library only. With `SOURCE_DATE_EPOCH` set the
artifacts are byte for byte reproducible. The inputs are pinned by
SHA-256 in both scripts, and the build refuses to overwrite artifacts of
a newer cleanup or content version.
