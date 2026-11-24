# Pinned upstream files

Unmodified copies, used by `TsakhurLayoutTests`, and kept for attribution.

| File | Repository | Path | Commit |
|---|---|---|---|
| `rus-3-rows.yaml` | https://github.com/Agisight/ios-system-keyboard | `layout/rus/rus-3-rows.yaml` | `86e000a966d5d5aa5282617d5f6d90c69890e8db` (2026-11-11) |
| `rus-longpress.yaml` | https://github.com/Agisight/ios-system-keyboard | `layout/rus/rus-longpress.yaml` | same |

The repository is MIT licensed: `LICENSE-ios-system-keyboard`
(Copyright (c) 2025 Agisight). `LICENSE-rf-keyboard-corpora`
(Copyright (c) 2025 Agisight (Ali Kuzhuget)) is kept beside it because
that repository was searched too; no file of it is used.

What the Tsakhur keyboard takes from them:

- `rus-3-rows.yaml`, `rus-longpress.yaml`: a transcription of the Russian
  iOS keyboard (letter rows, number and symbol pages, symbol alternates),
  the baseline the Tsakhur layout departs from by two keys.

Not available upstream: anything Tsakhur. Checked on 2026-11-23 at the
heads of both repositories:

- `Agisight/ios-system-keyboard` at `86e000a966d5d5aa5282617d5f6d90c69890e8db`
  has 28 folders under `layout/` (abk abq ady alt ava bak bua che chv dar
  gag gld kaz kbd kjh kom lez mhr oss rus sah tat tle tyv udm ulc xal
  xdq). There is no `layout/tkr`, and no file of the repository mentions
  `tkr`, Tsakhur or «цахур».
- `Agisight/rf-keyboard-corpora` at `cd7a94ee8318b1abb7690b93755242fd73aaf1b5`
  has 53 language folders under `data/`. There is no `data/tkr`: no
  layout, no layout stub, no long-press mapping and no letter count, and
  `languages.csv`, the summaries and the result tables do not list the
  language. (Its neighbours `rut`, `agx`, `lbe` and `tab` each have a
  folder with a stub or a mapping; Tsakhur has none.)

So the layout is LekiTech's own, and its letter statistics come from
Tsakhur text measured for this project (`docs/layout/nur_sample.json`)
and from the keyboard's dictionary. See `docs/LAYOUT.md`.
