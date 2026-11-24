# Tsakhur Keyboard for iOS

A native iOS keyboard for the Tsakhur language (ЦӀаӀхна миз), developed by
[LekiTech](https://github.com/LekiTech) on the shared **General Keyboard**
engine, next to the Avar, Lezgi, Dargwa, Kumyk, Tabasaran, Lak and Aghul
keyboards.

Tsakhur is written in Cyrillic in Dagestan and in a Latin alphabet in
Azerbaijan. This keyboard is **Cyrillic**: the alphabet of 1990, the
script of the literary language of Dagestan and of the newspaper «Нур»
([docs/LAYOUT.md](docs/LAYOUT.md#which-tsakhur)).

## The keyboard

- **The LekiTech Tsakhur layout** (a proposal, designed from letter counts
  of Tsakhur newspaper text; not an Apple or Agisight layout, and none
  exists): the Russian iOS layout with two keys changed. The hard sign
  **ъ** (3.3 % of all letters) and the palochka **Ӏ** (2.4 %) have their
  own keys, where Russian has щ (0.03 %) and э (0.25 %).

  ```
  й ц у к е н г ш ъ з х
  ф ы в а п р о л д ж Ӏ
  ⇧ я ч с м и т ь б ю ⌫
  ```

  Unlike the sibling keyboards, the palochka does not take the key of
  «ы»: in Tsakhur «ы» is the fifth most frequent letter.
- Long press: г → гь гъ гӀ · к → къ кӀ кь · х → хъ хь · а о у ы → аӀ оӀ
  уӀ ыӀ · п т ц ч → пӀ тӀ цӀ чӀ · д → дж · л → лʼ · ь → ʼ · е → ё ·
  ш → щ · Ӏ → э. The seventeen two-character letters of the alphabet are
  ordinary sequences and can also be typed key by key; long vowels and
  doubled consonants («аа», «лл») are typed by tapping the key twice. Why
  this layout, the numbers and the alternatives:
  [docs/LAYOUT.md](docs/LAYOUT.md).
- **The palatalization mark** of Tsakhur spelling («йигъылʼ», «мизʼ») is
  typed as ʼ (U+02BC) under «ь», and as «лʼ» under «л». It belongs to its
  word: the word is suggested and learned whole, and a word typed
  elsewhere with «’» still matches.
- The palochka is always **Ӏ U+04C0** in what you see and type; lookups use
  ӏ U+04CF internally, so words typed with a Latin I elsewhere still match.
- Word suggestions from an offline dictionary of 1,355 Tsakhur words and
  134 word pairs, plus the words and word pairs the keyboard learns from
  your own typing (after three uses by default), including next-word
  suggestions. **The dictionary is small and has no word frequencies**:
  its only source is one word list of dictionary forms. It was rebuilt
  from that list because the earlier reading had cut every word with «й»
  or with the mark in two (273 words restored, 314 pieces removed), and it
  **has not been verified by a native speaker**: 102 items are listed for
  review, 28 of them first. See [docs/DICTIONARY.md](docs/DICTIONARY.md).
- Matches the native iOS keyboard (Apple's measured iPhone grid, key
  previews, callout menus with swipe selection, caps lock,
  auto-capitalization, spacebar cursor control, hold-to-repeat delete),
  light and dark mode, the emoji page, an in-keyboard settings panel.
- Private by design: never asks for Full Access and sends nothing anywhere.
  Learned words live in the keyboard's own storage and can be managed and
  reset from the keyboard's gear key.

Status: **development version, not released on the App Store, not yet
tried on a phone by a Tsakhur speaker.** Open for review: the layout's
open questions ([docs/LAYOUT.md](docs/LAYOUT.md#open-questions)), the
dictionary's review lists
([docs/dictionary/review/](docs/dictionary/review/)), the self-name on the
Home Screen and a Tsakhur translation of the key names and settings panel,
which use Russian text for now ([docs/LOCALIZATION.md](docs/LOCALIZATION.md)).

## Building

The keyboard engine is the shared **General Keyboard** Swift Package
([LekiTech/GeneralKeyboard-iOS](https://github.com/LekiTech/GeneralKeyboard-iOS)),
linked as a local package found next to this checkout, on its `main`
branch:

```
<workspace>/
  GeneralKeyboard-iOS/     the engine package
  TsakhurKeyboard-iOS/     this repository
```

`GeneralKeyboard-iOS` is a private repository; cloning it needs read access.

The Xcode project references the package as `../../GeneralKeyboard-iOS`
(relative to `TsakhurKeyboard/TsakhurKeyboard.xcodeproj`) and the test
package as `../GeneralKeyboard-iOS`; nothing else is required (no tokens,
no package registry). Open
**`TsakhurKeyboard/TsakhurKeyboard.xcodeproj`** in Xcode 27, pick the
**`TsakhurKeyboard`** scheme (it builds and embeds the
`TsakhurKeyboardExtension` target) and run on a simulator or an iPhone.

```bash
xcodebuild build -project TsakhurKeyboard/TsakhurKeyboard.xcodeproj -scheme TsakhurKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2' -derivedDataPath build/DerivedData
xcodebuild test -scheme TsakhurCoreTests-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2' -derivedDataPath build/DerivedData-tests
```

Installing on an iPhone, step by step: [docs/BUILDING.md](docs/BUILDING.md).

## Identity

Provisional until the first release.

| | Debug (development) | Release (App Store) |
|---|---|---|
| App bundle ID | `org.lekitech.tsakhurkeyboard.dev` | `org.lekitech.tsakhurkeyboard` |
| Keyboard extension bundle ID | `org.lekitech.tsakhurkeyboard.dev.TsakhurKeyboardExtension` | `org.lekitech.tsakhurkeyboard.TsakhurKeyboardExtension` |
| App Group (both targets) | `group.org.lekitech.tsakhurkeyboard.dev` | `group.org.lekitech.tsakhurkeyboard` |
| Signing | automatic, the developer's own team | manual: the distribution team adds its team and App Store profiles |

Both targets carry the App Groups entitlement; the group's identifier is
the `TSAKHUR_APP_GROUP_ID` build setting of each configuration. Learned
words, settings and recent emojis live in the extension's own container,
so nothing is shared with the sibling keyboards.

The keyboard's language is `tkr` (ISO 639-3, `PrimaryLanguage` in the
extension's `Info.plist`) and must stay so
([docs/LOCALIZATION.md](docs/LOCALIZATION.md#the-language-code)).

## Release and App Store handoff

Debug builds run as they are under the developer's team. The Release
configuration is prepared but deliberately unsigned: it carries the App
Store identifiers, manual signing with `Apple Distribution`, and an empty
team and empty profile names. To archive for the App Store, the
distribution team:

1. Registers the App IDs `org.lekitech.tsakhurkeyboard` and
   `org.lekitech.tsakhurkeyboard.TsakhurKeyboardExtension`, creates the
   App Group `group.org.lekitech.tsakhurkeyboard`, and enables the App
   Groups capability with that group on both App IDs.
2. Creates an App Store provisioning profile for each of the two App IDs.
3. In the **Release** configuration of both targets (`TsakhurKeyboard`
   and `TsakhurKeyboardExtension`) sets `DEVELOPMENT_TEAM` and
   `PROVISIONING_PROFILE_SPECIFIER`. Debug stays as it is.
4. Sets the version in both targets, the same values in each:
   `MARKETING_VERSION` (now 1.0.0) and `CURRENT_PROJECT_VERSION` (now 1).
5. Archives the `TsakhurKeyboard` scheme (Product → Archive) and uploads
   the archive to App Store Connect.

Before signing is set up, this checks that Release compiles:

```bash
xcodebuild build -project TsakhurKeyboard/TsakhurKeyboard.xcodeproj -scheme TsakhurKeyboard \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath build/DerivedData-release
```

The keyboard does not request Full Access (`RequestsOpenAccess` is false)
and sends nothing anywhere, and `ITSAppUsesNonExemptEncryption` is NO. The
bundle identifiers and the App Group are provisional until the first
upload and must not change after it.

## Repository

```
TsakhurKeyboard/
  TsakhurKeyboard.xcodeproj    two targets: the app and the keyboard extension
  TsakhurKeyboard/             containing app (SwiftUI): install steps, layout,
                               long-press guide, settings and dictionary info
  TsakhurKeyboardExtension/    the keyboard: TsakhurDefinition (with the Tsakhur
                               normalization profile), TsakhurLayout, TsakhurStrings,
                               TsakhurIdentity, KeyboardViewController, Info.plist,
                               tsakhur_words.sqlite, tsakhur_bigrams.sqlite
Package.swift, Tests/TsakhurCoreTests/  product-layer tests through the real engine
  Fixtures/agisight/                    pinned upstream files (MIT) the tests read
dictionary-source/                      the inputs of the dictionary, read-only:
  original-v0/                          the Tsakhur files of keyboard_data_v0.zip
  upstream/ids-bf6c9f8/                 the 1,440 IDS rows they were made from (CC BY 4.0)
scripts/derive_source_repairs.py        derives scripts/data/*.tsv from the IDS rows
scripts/data/                           the five source-repair tables the build applies
scripts/build_dictionary.py             reproducible dictionary build from the v0 data
scripts/measure_newspaper_sample.py     letter counts of a newspaper sample (network)
scripts/analyze_layout.py               letter statistics and the layout comparison
scripts/make_icon.py                    checks and installs the app icon from docs/branding/
docs/                                   LAYOUT (+ layout/), DICTIONARY (+ dictionary/review/),
                                        LOCALIZATION, BUILDING, branding/ (the icon artwork
                                        as delivered)
```

The engine itself (model, views, storage, normalization pipeline,
settings, emoji) is not in this repository; see `GeneralKeyboard-iOS/docs/`.
No engine change was needed for Tsakhur.

## Organization

Developed by [LekiTech](https://github.com/LekiTech), a team building
digital tools for the languages of Dagestan.

## License

All rights reserved, see [LICENSE](LICENSE). Third-party material and its
licenses are listed there.
