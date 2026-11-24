# Dictionary sources

Read-only inputs of `scripts/derive_source_repairs.py` and
`scripts/build_dictionary.py`. Nothing here is edited; the checksums are in
each folder's `SHA256SUMS`.

## original-v0/

The Tsakhur files of `keyboard_data_v0.zip` (SHA-256 `8cec9c22…b8ac31`,
folder `keyboard_data/`, built 2026-10-11), as extracted:

| File | What it is |
|---|---|
| `tkr_words.tsv`, `tkr_words.sqlite` | 1,396 words, every one with `base_score` 1 (a word-list entry, no corpus count) |
| `tkr_bigrams.tsv`, `tkr_bigrams.sqlite` | no rows: v0 has no Tsakhur word pairs |
| `tkr_stats.json` | the v0 builder's summary: one source, `ids`, a lexicon of 1,396 words |

The archive's two general files, `README.md` and `build_kb_data.py`
(the v0 builder for all nine languages), are kept beside them in a working
checkout and are not tracked in this repository; `SHA256SUMS` lists them.

## upstream/ids-bf6c9f8/

`forms_tsakhur_70.csv`: the 1,440 rows with `Language_ID` 70 («Tsakhur»,
author Madzhid Khalilov, data entry Stefan Lange) of `cldf/forms.csv` in
https://github.com/intercontinental-dictionary-series/ids at commit
`bf6c9f8c7d25c15e61e338f3ed29ae46b844c0f8` (2026-10-09), copied byte for
byte with the header line. SHA-256 of the whole upstream `forms.csv`:
`1ff6caa439d27d05c0ce7e72b656bfae5595bc5d12ae57b494e481e90e4e9968`.

This is the list v0 read: replaying the v0 reader on these rows gives
exactly the 1,396 words of `tkr_words.tsv`
(`scripts/derive_source_repairs.py` checks it on every run).

Licence: Creative Commons Attribution 4.0 International (`LICENSE`, the
upstream file). Cite as: Key, Mary Ritchie & Comrie, Bernard (eds.) 2023.
*The Intercontinental Dictionary Series.* Leipzig: Max Planck Institute
for Evolutionary Anthropology. https://ids.clld.org

Not used: IDS list 532, «Tsakhur (Gelmets dialect)», 1,381 forms of
another dialect, which v0 did not read either.
