# Building, signing, running on a device

## Requirements

- Xcode 27 (the project was created with 27.2); iOS 18.0 deployment target.
- `GeneralKeyboard-iOS` checked out next to this repository (`main`). The
  project references it as a local Swift package (`../../GeneralKeyboard-iOS`
  from the `.xcodeproj`); no tokens or registries. Nothing of the engine is
  copied into this repository.

## Targets and identity

Exactly two targets: `TsakhurKeyboard` (the app) and
`TsakhurKeyboardExtension` (the keyboard).

| | Debug (development) | Release (App Store) |
|---|---|---|
| App bundle ID | `org.lekitech.tsakhurkeyboard.dev` | `org.lekitech.tsakhurkeyboard` |
| Extension bundle ID | `org.lekitech.tsakhurkeyboard.dev.TsakhurKeyboardExtension` | `org.lekitech.tsakhurkeyboard.TsakhurKeyboardExtension` |
| App Group (`TSAKHUR_APP_GROUP_ID`, both entitlements) | `group.org.lekitech.tsakhurkeyboard.dev` | `group.org.lekitech.tsakhurkeyboard` |
| Signing | Automatic, team `RC94H8KQYA` | Manual, `Apple Distribution`, team and profiles empty |
| Display name | app: Tsakhur / ЦӀаӀхна миз · keyboard: Tsakhur / Цахурский | same |

Debug and Release use different identifiers on purpose: bundle IDs and App
Groups are unique across Apple developer teams, so a Debug build registered
under the developer's team must not take the production identifiers away
from the distribution team. `TsakhurIdentity.swift` selects the App Group
with `#if DEBUG` to match. The learned-word store (`learned.sqlite`),
settings (`UserDefaults.standard` of the extension) and recent emojis live
in the extension's own container, keyed by its bundle ID, so Tsakhur never
shares or touches the data of the Avar, Lezgi, Dargwa, Kumyk, Tabasaran,
Lak or Aghul keyboards. The App Group only carries the inert contribution
bridge.

The keyboard definition id (`KeyboardDefinition.id`) is the Release
extension bundle ID and never changes.

## Development build on a physical iPhone

1. Open `TsakhurKeyboard/TsakhurKeyboard.xcodeproj`, scheme
   `TsakhurKeyboard`, configuration Debug (the scheme's default).
2. Connect the iPhone, select it as the run destination and press Run.
   Automatic signing with team `RC94H8KQYA` creates the two App IDs, the
   App Group `group.org.lekitech.tsakhurkeyboard.dev` and the development
   profiles on first use (Xcode asks once; a paid team, so no 7-day
   expiry).
3. On the phone: Settings → General → Keyboard → Keyboards → Add New
   Keyboard → **Tsakhur** (on a phone set to Russian: **Цахурский**). The
   app's own screen repeats these steps and its button opens Settings.
4. In any text field hold 🌐 and pick the keyboard.
5. Full Access is never requested and must stay off.

Command line, for a connected device (take the id from
`xcrun devicectl list devices`):

```bash
xcodebuild build -project TsakhurKeyboard/TsakhurKeyboard.xcodeproj -scheme TsakhurKeyboard \
  -configuration Debug -destination 'id=<device udid>' -allowProvisioningUpdates
```

What to look at on the phone, since none of it can be judged on a
simulator: the Home Screen name «ЦӀаӀхна миз» on a Russian phone (does it
fit?), the keys «ъ» and «Ӏ», the long presses of `docs/LAYOUT.md`
(above all «ь» → «ʼ» and «л» → «лʼ»), a word with the mark being
suggested after it was typed three times, and the globe menu.

## Simulator

```bash
xcodebuild build -project TsakhurKeyboard/TsakhurKeyboard.xcodeproj -scheme TsakhurKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2' \
  -derivedDataPath build/DerivedData
```

`-derivedDataPath build/DerivedData` keeps the build products inside this
checkout (`build/` is ignored by Git), apart from every other project's.
Install the built `.app`, enable the keyboard in the simulator's Settings
as above, then type in any text field. Older simulator runtimes may lack
the emoji font; the emoji page then shows boxes there.

Checked on 2026-11-23 on an iPhone 18 Pro simulator (iOS 27.2, a device
created for this check and deleted after it): the app opens with its icon,
its title and «ЦӀаӀхна миз»; the globe menu lists the keyboard as
«Tsakhur» with the language line «Tsakhur» under it; the keyboard shows
the three rows of `docs/LAYOUT.md`, flashes «ЦӀаӀхна миз» on the space bar
and then shows «ЦӀАӀХ» in its corner; «к», «Ӏ», «ы» bring up «кӀыл» and
«кӀыч» from the dictionary; «л» and a long press on «ь» give «кӀылʼ» and
the suggestion «кӀылʼна»; tapping it inserts the word with its space and
offers «йичи» and «чодж» as the next word; long presses on «г» and «а»
insert «гъ» and «аӀ»; the settings panel opens with «Обычно — 3 раза»
selected under learning; the emoji page, dark mode and the 🌐 key work.
The Russian Home Screen name was not seen (the app's icon did not come up
on the simulator's Home Screen), so whether «ЦӀаӀхна миз» fits under the
icon is still to be looked at on a phone. This is a simulator check, not a
test on a phone and not a review by a speaker.

## Tests

```bash
xcodebuild test -scheme TsakhurCoreTests-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.2' \
  -derivedDataPath build/DerivedData-tests
```

`Package.swift` compiles the product files of the extension into
`TsakhurCore` and runs them through the real engine: the definition, the
normalization profile with the palatalization mark, the palochka
convention, the word separators and the project identity
(`TsakhurDefinitionTests`, 12), the layout against the pinned Russian
baseline, every long press, the alphabet and the letter counts the
layout rests on (`TsakhurLayoutTests`, 10), the shipped artifacts, the
words the v0 reading had cut and the pairs (`DictionaryTests`, 9), typing,
digraph insertion in every case, words with the mark, accepted
suggestions, learning, the learned next word, persistence, settings and
the default learning speed (`TypingAndLearningTests`, 19). 50 tests.

`xcodebuild test` sometimes does not exit after printing the summary of
the last suite; stop it then, the results above the summary stand.

## Release signing (later, by the distribution owner)

The Release configuration carries the App Store identifiers and manual
signing with an empty team and empty profile names. Before the first
archive the distribution team must:

1. register the App IDs `org.lekitech.tsakhurkeyboard` and
   `org.lekitech.tsakhurkeyboard.TsakhurKeyboardExtension` and the App Group
   `group.org.lekitech.tsakhurkeyboard` in its developer account, with the
   App Groups capability on both App IDs;
2. create two App Store provisioning profiles and set, in the Release
   configuration of each target, `DEVELOPMENT_TEAM[sdk=iphoneos*]` and
   `PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]` (as Avar and Lezgi do);
3. keep Debug untouched, so development builds stay under the developer's
   own team.

Until then this checks that Release compiles:

```bash
xcodebuild build -project TsakhurKeyboard/TsakhurKeyboard.xcodeproj -scheme TsakhurKeyboard \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath build/DerivedData-release
```

Nothing here uses another developer's credentials, and no certificate or
profile is committed.

## Conventions

Exactly two targets. No sticker extension, no messenger integrations, no
advertising, analytics, subscriptions or third-party packages (General
Keyboard `docs/ADDING_A_KEYBOARD.md`). Engine changes go to
`GeneralKeyboard-iOS` first; this repository holds only the Tsakhur
definition, resources, tests and documentation. No engine change was
needed for Tsakhur: its normalization profile (`tsakhur-cyrillic`, the
Dagestanian rules plus the palatalization mark) is a value of the
product, in `TsakhurDefinition.swift`.
