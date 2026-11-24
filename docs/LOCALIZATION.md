# Naming, localization and strings for review

## Names on the device

| Where | English and other languages | Russian |
|---|---|---|
| Home Screen (app `InfoPlist.xcstrings`, `CFBundleDisplayName` and `CFBundleName`) | Tsakhur | ЦӀаӀхна миз |
| Keyboard list and globe menu (extension `InfoPlist.xcstrings`) | Tsakhur | Цахурский |
| Title on the app's screen | Tsakhur Keyboard | Цахурская клавиатура |

English is the development language and the fallback for every language
other than Russian; the target's `INFOPLIST_KEY_CFBundleDisplayName`
(«Tsakhur») is only the unlocalized fallback. The Russian localization of
the app carries the language's own name, as approved for the sibling
keyboards (Авар мацӀ, Дарган мез, Къумукъ тил, Табасаран чӀал, Лакку маз,
Агъул чӀал). The extension's names are set separately and are the
language name only.

«ЦӀаӀхна миз» is eleven characters with its space, as long as «Къумукъ
тил», which fits every supported iPhone, and its two palochkas are narrow.
It was not measured on a device. If it should not fit a 375 pt iPhone,
iOS first drops the space («ЦӀаӀхнамиз») and then cuts the name.

## The self-name: ЦӀаӀхна миз

| Source | Form |
|---|---|
| Russian Wikipedia, «Цахурский язык» (infobox and first line) | ЦӀаӀхна миз |
| English Wikipedia, «Tsakhur language» | цӀаӀхна миз |
| Omniglot, «Tsakhur» | цӀаӀхна миз |
| Azerbaijani Wikipedia, «Saxur dili» | цIаIхна миз |
| The newspaper «Нур» (sample of 2026) | «цӀаӀхни мизелин», «цӀаӀхни мизел'» (the oblique forms), «цӀаӀхбышда миз», «едина миз» and «едина миз'» |

The four reference pages agree on «цӀаӀхна миз», and the newspaper has
both words in running text, with the attribute in «-на» before «миз» in
the absolutive («едина миз», the mother tongue). The exact phrase
«цӀаӀхна миз» did not occur in the 42 articles read. One thing is open:
the newspaper prints the word for "language" both as «миз» (10 times) and
with the palatalization mark, «миз'» (8 times); the reference pages and
the dictionary's source have «миз». **A Tsakhur speaker should confirm
the name before release.**

The name is capitalized as a title, «ЦӀаӀхна миз». Both palochkas are
Ӏ U+04C0 everywhere in the project. Sources type it in several ways
(U+04C0, a Latin I, l); the letter meant is the same.

## What is Tsakhur today

| Where | String | Source |
|---|---|---|
| Home Screen name (Russian), keyboard name (flashed on the space bar), app header | ЦӀаӀхна миз | above |
| Space bar corner label | ЦӀАӀХ | the stem of the self-name and the Tsakhur name of the village («ЦӀаӀх» in the Tsakhur Wikipedia incubator; «цӀаӀхни», «цӀаӀхбы» in «Нур»), like «ЛЕЗГ», «АВАР», «ДАРГ», «КЪУМ», «ТАБ», «ЛАК», «АГЪУЛ» |

Nothing else is Tsakhur yet. **No Tsakhur translation was invented.**

## What is temporary Russian (needs a Tsakhur translation)

No verified Tsakhur translation of the key names or of the keyboard's
settings panel exists (Agisight's `ios-system-keyboard` has no Tsakhur
key names), so `TsakhurStrings.swift` uses Russian. Every string below
needs a reviewed Tsakhur version:

| Field | Russian (current) |
|---|---|
| space | Пробел |
| return key: Go / Send / Done / Next / Continue / Join / Route / Search | Перейти / Отправить / Готово / Далее / Продолжить / Подкл. / Маршрут / Найти |
| emergency call | SOS |
| lettersKey | АБВ |
| deleteWordQuestion | Удалить «…»? |
| no / delete | Нет / Удалить |
| emojiRecents | Недавние |
| back / close | Назад / Клавиатура |
| settingsCaption / settingsTitle | ЦАХУРСКАЯ КЛАВИАТУРА / Настройки |
| pageInput / pageTheme / pageDictionary / pageAbout | Ввод / Тема / Словарь / О клавиатуре |
| sectionLayout / sectionSuggestions / sectionKeys / sectionLearning | Раскладка / Подсказки / Клавиши / Обучение |
| sectionLongPress / sectionTheme | Долгое нажатие (кӀ, хь, ё…) / Тема |
| wordSuggestions / nextWordSuggestion / autoSpace | Подсказки слов / Подсказка следующего слова / Пробел после подсказки |
| doubleSpacePeriod / spaceCursor / spaceCornerToggle | Два пробела — точка / Курсор пробелом / «цӀаӀх» на пробеле |
| learnFast / learnNormal / learnSlow / learnUses | Быстро / Обычно / Медленно / N раз(а) |
| calloutShort / calloutNormal / calloutLong / calloutDuration | Короткая задержка / Обычная задержка / Длинная задержка / 0,3 с |
| themeSystem / themeLight / themeDark | Системная / Светлая / Тёмная |
| learnedWordsCaption / noWordsYet | выученные слова / Пока нет слов |
| deleteAll / deleteAllQuestion | Удалить все выученные слова / Удалить все выученные слова? |
| aboutInitial / aboutTitle / aboutByline | Ц / Цахурская клавиатура / Версия … · LekiTech |
| settingsTitle / settingsSubtitle of the layout style | Стандартная / Русская раскладка, ъ на месте щ, Ӏ на месте э |
| emojiCategoryTitles | Смайлики и люди, Животные и природа, Еда и напитки, Активность, Путешествия и места, Предметы, Символы, Флаги |

Also the extension's `Localizable.xcstrings` («Show «цӀаӀх» on the space
bar», en/ru) and the display name «Tsakhur» / «Цахурский» in the keyboard
extension's `InfoPlist.xcstrings` (a Tsakhur display name could be added
as a `tkr` localization).

The engine's own labels (for example the explanatory subtitles under the
toggles) follow the system language (en/ru) and are not this keyboard's to
translate.

## The language code

`PrimaryLanguage` of the extension is `tkr`, the ISO 639-3 code of
Tsakhur and a valid BCP 47 language subtag. Unlike `agx`, `lbe`, `tab`
and `rut`, Apple's language data has a name for it:
`Locale.localizedString(forLanguageCode: "tkr")` returns «Tsakhur»
(checked with Foundation on macOS 26.6; the Russian locale has no Russian
name and returns «Tsakhur» as well). The globe menu may therefore show a
language line «Tsakhur» under the keyboard's name, on a Russian iPhone
too. That line is Apple's, not this project's. The code must not be
replaced by another language's.

## The containing app

English with Russian translations (`TsakhurKeyboard/Localizable.xcstrings`,
31 strings), like the sibling apps: «Tsakhur Keyboard» / «Цахурская
клавиатура». No Tsakhur text there except letters, two example words
with the palatalization mark («йигъылʼ», «мизʼ», as the newspaper prints
them) and «ЦӀаӀхна миз». The app shows no contributor credits;
attribution of third-party material is in the repository (`LICENSE`,
`Tests/TsakhurCoreTests/Fixtures/agisight/SOURCE.md`,
`dictionary-source/README.md`, `docs/DICTIONARY.md`).

## Icon and colours

`docs/branding/TsakhurKeyboard_AppIcon_1024.webp` is the owner's approved
artwork as delivered (1024 × 1024, opaque RGB, full bleed, SHA-256
`43bc3456…699661`): the Tsakhur flag, a green field above, a white field
with a black mountain, seven black stars and the traditional signs under
the mountain, a red field below with a white keyboard. It arrived as a
chat attachment in WebP; no file named `TsakhurKeyboard_AppIcon_1024.png`
was in the workspace. `scripts/make_icon.py` checks it and installs it
without changing a pixel (`AppIcon-1024.png`, a lossless PNG of the same
pixels, and `AppLogo.png` at 512 × 512 for the app's header); it prefers a
`.png` of that name in `docs/branding/` if one is added. The app's
colours come from the artwork: `AccentColor` is its green (#027906;
#3CC864 in dark mode), `BrandTint` its red, deepened a little so that
small text stays readable on a light background (#CC0101 for the
artwork's #EE0102; #FF6259 in dark mode).
