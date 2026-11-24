# The Tsakhur layout

The layout is **LekiTech's own proposal**. It is not an Apple layout, not
an Agisight layout and not an official standard: none exists for Tsakhur.
It was designed from letter counts of Tsakhur text and has not yet been
tried by Tsakhur speakers. The open questions are at the end.

## Which Tsakhur

Tsakhur (ISO 639-3 `tkr`, self-name «ЦӀаӀхна миз») is written in two
scripts today.

| Where | Script | Since | Source |
|---|---|---|---|
| Dagestan (Russia) | Cyrillic, the alphabet of G. Kh. Ibragimov and N. G. Isaev | approved 1990, taught from 1992, primer 1993 | «Языки народов Российской Федерации и соседних государств», vol. 3 (2005), pp. 334–336; «Письменные языки мира: Языки Российской Федерации», vol. 2 (2003), p. 567 |
| Azerbaijan | Latin, on the Azerbaijani alphabet | 1996 (primer «AӀlifbey»), reformed in the 2010s (dictionary of 2015) | Sackett 2017, *Community-Driven, Goal-Centred Orthography Development: A Tsakhur Case Study* |
| earlier | Latin of 1934–1938 (A. N. Genko), Arabic script before it | — | Ibragimov 1990, *Цахурский язык*, pp. 3–4 |

This keyboard is **Cyrillic only**: it is the script of the literary
language of Dagestan (based on the Tsakh-Suvagil dialect), of the
newspaper «Нур», and of every word in the keyboard's dictionary. The
Latin alphabets are not supported and no word is transliterated from
them: the two scripts do not map letter for letter (the Latin of 2015
writes «ə» where the Cyrillic writes «аӀ», «ts'» for «цӀ», «q» for «хъ»),
and a second writing system would be a second keyboard.

The Cyrillic alphabet of 1990 has 50 letters, the 33 Russian ones and
17 two-character letters:

```
А АӀ Б В Г ГӀ Гъ Гь Д Дж Е Ё Ж З И Й К КӀ Къ Кь Л М Н О ОӀ
П ПӀ Р С Т ТӀ У УӀ Ф Х Хъ Хь Ц ЦӀ Ч ЧӀ Ш Щ Ъ Ы ЫӀ Э Ь Ю Я
```

The palochka makes ejective consonants after к п т ц ч (and «гӀ») and
pharyngealized vowels after а о у ы. Three things the alphabet table
does not show are part of the spelling in print, and the layout takes
all three from the text itself:

- **The palatalization mark.** A soft consonant is marked with an
  apostrophe after it: «йигъыл'», «вахтал'», «миз'», «кӀыл'на». The soft
  sign cannot do it, because «гь», «кь» and «хь» are letters of their
  own. See [the palatalization mark](#the-palatalization-mark).
- **Long vowels are written twice**: «мааъад», «хивее», «гьоо». Doubled
  consonants too: «гьаммаше», «баттагъ».
- **«ъ» after a vowel** is the glottal stop: «мааъад», «джаӀмаъаӀт».

## What Agisight has: nothing (scenario B)

Both repositories were checked at their heads on 2026-11-23
(`Tests/TsakhurCoreTests/Fixtures/agisight/SOURCE.md`):

- `Agisight/ios-system-keyboard` at `86e000a`: 28 layouts, no `layout/tkr`,
  no mention of the language.
- `Agisight/rf-keyboard-corpora` at `cd7a94e`: 53 language folders, no
  `data/tkr`. Not a layout, not a stub, not a long-press mapping, not a
  letter count. (Rutul, Aghul, Lak and Tabasaran each have at least a
  stub or a mapping there; Tsakhur has none.)

So there was no layout to follow and no upstream frequency table. The
layout was designed here, by the process used for Kumyk, Tabasaran, Lak
and Aghul, and it does not copy any of them: the letter counts of
Tsakhur rule out the arrangement three of them share.

## The data

The keyboard's dictionary is a word list of 1,355 dictionary forms
without frequencies (`docs/DICTIONARY.md`), so it cannot say how often a
letter is typed. The typing frequencies come from the only Tsakhur
newspaper, **«Нур»** (Makhachkala, since 1995), which publishes its
Tsakhur pages at https://nur-05.ru/archives/nationals/ .
`scripts/measure_newspaper_sample.py` read the 44 newest articles on
2026-11-23, left out one in Russian and one printed twice, and wrote
letter counts, nothing else, to `docs/layout/nur_sample.json`:
**42 articles, 20,326 words, 150,195 letters** (7.4 letters per word).
The articles are not in this repository and are not a source of the
dictionary.

Share of all letters, in percent:

```
а 15.7  и 7.7  н 7.2  е 6.0  ы 4.6  д 3.8  л 3.5  м 3.4  р 3.4  б 3.4
ъ 3.3   к 3.3  г 3.2  х 3.2  с 3.1  й 2.9  в 2.8  ш 2.7  ь 2.7  у 2.6
Ӏ 2.4   т 2.4  о 1.9  ж 0.8  з 0.8  ч 0.7  ʼ 0.5  я 0.5  п 0.3  ц 0.3
ф 0.3   э 0.25 ю 0.16 ё 0.07 щ 0.03
```

Per 100 words:

| Letter | per 100 words | What it is in Tsakhur |
|---|---|---|
| ы | 34.1 | a vowel of its own, the fifth most frequent letter: «ыхьа», «йигъыл'», «Дагъыстан» |
| ъ | 24.6 | the tail of «гъ», «хъ», «къ» (18.3) and the glottal stop |
| Ӏ | 17.8 | «аӀ» 9.4, «кӀ» 3.0, «цӀ» 1.7, «оӀ» 0.9, «чӀ» 0.9, «ыӀ» 0.8, «тӀ» 0.7, «уӀ» 0.4 |
| ʼ | 3.8 | the palatalization mark, in 3.7 % of all words, after «л» 712 times of 764 |
| э | 1.9 | mostly the first letter of a word: «эскер», «экӀда» |
| ю | 1.2 | «югун», «ющенаъа» |
| ё | 0.5 | Russian names and loans |
| щ | 0.2 | «ваӀщеле»; rare |

The two-character letters of the alphabet come 61 times in 100 words:
гь 11.4, аӀ 9.4, хъ 8.4, гъ 5.9, дж 5.9, хь 5.7, къ 4.1, кӀ 3.0, кь 1.9,
цӀ 1.7, оӀ 0.9, чӀ 0.9, ыӀ 0.8, тӀ 0.7, уӀ 0.4, гӀ 0.04, пӀ 0.03.
Doubled vowels: «ее» 4.6, «аа» 3.5, «оо» 0.9.

The dictionary agrees on what is everyday and what is rare, although its
words are citation forms (many infinitives in «-ас») counted once each:
Ӏ 4.2 %, ъ 3.3 %, ы 3.7 %, ʼ 0.8 %, э 0.3 %, щ 0.05 %.

How the newspaper types the two special characters, for the record: the
palochka as a Latin «I» (3,598 times; «l» 25 times), never as U+04C0;
the mark as the ASCII apostrophe (702 times) or «’» (62 times).

## The candidates

All numbers are from `scripts/analyze_layout.py` (`docs/layout/analysis.json`).
It is a model of typing, not a measurement of people: a letter with a key
is one tap, a letter without one is one long press (0.3 s more), no
suggestion is picked.

| | Layout | Long presses per 100 words | Keys per row | Narrowest key, 402 / 375 pt screen | Keys changed from Russian |
|---|---|---|---|---|---|
| A | Russian iOS keyboard; ъ, Ӏ and ʼ under a long press on ь | **46.7** | 11 11 9 | 29.9 / 27.5 pt | 0 |
| **B** | **ъ on щ's key, Ӏ on э's key; ʼ under ь** | **6.3** | 11 11 9 | 29.9 / 27.5 pt | 2 |
| B-ю | ъ on щ's key, Ӏ on ю's key; ʼ under ь | 5.6 | 11 11 9 | 29.9 / 27.5 pt | 2 |
| S | ъ on щ's key, Ӏ on ы's key (Dargwa, Tabasaran, Aghul) | 38.5 | 11 11 9 | 29.9 / 27.5 pt | 2 |
| L | Ӏ on ы's key, ъ on э's key (Lak) | 40.2 | 11 11 9 | 29.9 / 27.5 pt | 2 |
| C | as B, and ʼ on ю's key | 3.7 | 11 11 9 | 29.9 / 27.5 pt | 3 |
| D | twelve keys in two rows: all Russian letters, ъ and Ӏ | 4.3 | 12 12 9 | 26.9 / 24.7 pt | 0 moved, 2 added |

What each long press is, per 100 words: A — ъ 24.6, Ӏ 17.8, ʼ 3.8, ё 0.5;
B — ʼ 3.8, э 1.9, ё 0.5, щ 0.2; S — ы 34.1 and the rest of B without э.

Thumb travel in the model differs little between them (52.6 to 56.3 pt
per letter over the dictionary's words) and did not decide anything.

Why **B**:

- **A is not usable.** Nearly every second word would need a long press:
  «ъ» and «Ӏ» are everyday letters, the 11th and the 21st of 35.
- **S and L, the sibling arrangements, do not fit Tsakhur.** They give
  the key of «ы» to the palochka. In Dargwa, Tabasaran, Lak and Aghul
  «ы» is a letter of loans; in Tsakhur it is the fifth most frequent
  letter, twice as frequent as the palochka. Moving it under a long press
  costs 34 long presses per 100 words. This is the one place where the
  family's layout could not be copied.
- **B changes two keys**, the number every sibling keyboard changes, and
  takes the two rarest letters of the Russian keyboard that are not
  needed elsewhere: «щ» (0.03 %) and «э» (0.25 %). «ъ» lands between
  «ш» and «з», two keys from «г» and from «х», whose digraphs «гъ» and
  «хъ» it closes 14 times in 100 words; that is also where the Dargwa,
  Kumyk, Tabasaran and Aghul keyboards have it. «Ӏ» lands at the end of
  the home row, on the other hand from «а», which it follows in half of
  its uses.
- **B-ю** would save 0.7 long presses per 100 words by taking «ю»
  instead of «э», and would put the palochka in the bottom corner beside
  the delete key. Not worth it.
- **C** gives the palatalization mark a key of its own in place of «ю»
  and saves another 2.6 long presses per 100 words. It was not chosen:
  it changes a third key and puts a non-letter among the letters, and
  the mark is the one part of the spelling whose code point and typing
  habit are still an open question (below). A long-press slot can be
  changed later without moving a key; a key cannot. If speakers find the
  mark tedious, C is the next step.
- **D** keeps every Russian letter on a key and saves 2 long presses per
  100 words against B, with keys 3 pt narrower (10 %) in two rows: 24.7 pt
  on a 375 pt iPhone. Not worth it for letters that rare.

## The layout

```
й ц у к е н г ш ъ з х
ф ы в а п р о л д ж Ӏ
⇧ я ч с м и т ь б ю ⌫
```

Row 1: `й ц у к е н г ш ъ з х` (ъ where the Russian keyboard has щ).
Row 2: `ф ы в а п р о л д ж Ӏ` (Ӏ where the Russian keyboard has э).
Row 3: `я ч с м и т ь б ю`, as Russian, between Shift and Delete.
The number and symbol pages, the bottom row and the emoji page are those
of the Russian iOS keyboard and of the sibling keyboards.

The palochka key shows and inserts **Ӏ U+04C0**, in every shift state.

### Long presses

| Key | Options | Why |
|---|---|---|
| г | гь гъ гӀ | letters of the alphabet, in the order of their frequency (11.4, 5.9, 0.04 per 100 words) |
| к | къ кӀ кь | 4.1, 3.0, 1.9 |
| х | хъ хь | 8.4, 5.7 |
| а о у ы | аӀ · оӀ · уӀ · ыӀ | the four pharyngealized vowels of the alphabet |
| п т ц ч | пӀ · тӀ · цӀ · чӀ | the ejectives |
| д | дж | a letter of the alphabet |
| л | лʼ | the commonest use of the mark: 93 % of its occurrences |
| ь | ʼ | the palatalization mark alone, for к з д т с and the rest |
| е | ё | as on the Russian keyboard |
| ш | щ | the letter that gave its key to ъ, under its neighbour in the alphabet |
| Ӏ | э | the letter that gave its key to Ӏ, on that key |

Every option is the plain sequence of its characters («кӀ» is к + U+04C0,
«лʼ» is л + U+02BC) and can be typed key by key as well; the long press
saves a tap, nothing more. All 17 two-character letters of the alphabet
have an option, each under its first letter. Doubled letters (the long
vowels «аа», «ее», «оо», the consonants «лл», «кк», «хх») are typed by
tapping the key twice. «ъ», «ж», «я», «ю» and the other keys have no
long press.

Not offered, on purpose: «хӀ», «аь» and «оь», which five and three words
of the dictionary's source write. They are not letters of the alphabet of
1990 and do not occur in the newspaper sample; they can be typed key by
key.

### The palatalization mark

The keyboard types the mark as **ʼ U+02BC, MODIFIER LETTER APOSTROPHE**.

- It is what the dictionary's source, the Tsakhur list of the
  Intercontinental Dictionary Series, uses («голʼ», «хылʼ», 67 words).
- It is a letter for Unicode, so the keyboard and the app being typed in
  both keep it inside the word: a double tap selects «йигъылʼ» whole, the
  word is learned and suggested whole. A typographic «’» at the end of a
  word reads as a closing quotation mark, and the ASCII apostrophe ends a
  word in every General Keyboard product.
- The newspaper prints «'» and «’». A word typed or pasted with «’», «‘»
  or «`» is looked up as the same word (the keyboard's normalization
  profile reads them as the mark), so text from other keyboards still
  gets suggestions. The ASCII apostrophe stays on the number page and
  stays a separator.

The mark is not a soft sign: «кокʼ» is not «кокь», whose «кь» is another
consonant. It extends the consonant before it the way «ъ», «ь» and «Ӏ»
do, so «улʼ» is a word of two letters for the keyboard.

## Open questions

For Tsakhur speakers and the owner. None of them blocks using the
keyboard.

1. **The code point of the mark.** U+02BC is the right character for the
   keyboard's logic, but the newspaper and everyday typing use the plain
   apostrophe. Would readers accept «ʼ», or should the keyboard insert
   «'» or «’»? (Either would need the keyboard to treat that character as
   part of a word.)
2. **Where the mark lives.** Under «ь» and, as «лʼ», under «л», at
   3.8 long presses per 100 words. Should it have its own key in place of
   «ю» (candidate C)?
3. **Ӏ on the key of «э»**, with «э» under it (1.9 long presses per 100
   words, mostly at the start of a word), or on the key of «ю»
   (candidate B-ю)?
4. **Vowel long presses.** «аӀ» is offered under «а», the most frequent
   key. Is the popup on a held «а» a help or a nuisance? Typing «а» and
   then «Ӏ» is two taps on two hands and is faster.
5. **«хӀ», «еӀ», «иӀ», «аь», «оь».** The word list has a few words with
   them; the alphabet and the newspaper do not. Are they needed, and
   under which keys?
6. **The sample.** 42 newspaper articles of autumn 2026 are a thin base
   (official prose, many Russian names). A larger and more varied sample
   would be welcome before the layout is called final.

## Reproducing the numbers

```bash
python3 -I scripts/measure_newspaper_sample.py --fetch 4 --cache build/research/nur/sample   # network; a later run gives a later sample
python3 -I scripts/analyze_layout.py                                                         # from the committed nur_sample.json
```

The first command is how `docs/layout/nur_sample.json` was made; the file
records the address and the SHA-256 of every article it counted. The
second needs only the committed files.
