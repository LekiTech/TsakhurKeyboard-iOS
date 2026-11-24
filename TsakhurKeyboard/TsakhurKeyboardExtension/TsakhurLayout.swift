//
//  TsakhurLayout.swift
//  TsakhurKeyboardExtension
//
//  The LekiTech Tsakhur layout (proposed; not an Apple or otherwise
//  official layout). It is the Russian iOS keyboard with two keys changed:
//  the hard sign «ъ» takes the place of «щ», and the palochka «Ӏ» takes the
//  place of «э». «щ» moves under a long press on «ш», «э» under «Ӏ».
//
//  Why: in Tsakhur newspaper text «ъ» is 3.3 % of all letters (25 per 100
//  words: «гъ», «хъ», «къ», and the glottal stop of «мааъад», «джаӀмаъаӀт»)
//  and the palochka 2.4 % (18 per 100 words: half of them the pharyngealized
//  vowel «аӀ», then «кӀ», «цӀ», «оӀ», «чӀ», «ыӀ», «тӀ», «уӀ»), while «щ» is
//  0.03 % and «э» 0.25 %. On the Russian layout «ъ» and «Ӏ» need a long
//  press, which the model puts at 47 long presses per 100 words; here it is
//  6, four of them the palatalization mark.
//
//  Unlike Dargwa, Tabasaran and Aghul, the palochka does NOT take the key
//  of «ы»: in Tsakhur «ы» is the fifth most frequent letter (4.6 %, 34 per
//  100 words: «ыхьа», «йигъыл», «Дагъыстан»). «э» is the rarest letter of
//  the Russian keyboard after «щ» and «ю».
//
//  The numbers, the alternatives that were compared and the open questions
//  are in docs/LAYOUT.md, computed by scripts/analyze_layout.py from a
//  sample of the newspaper «Нур» (docs/layout/nur_sample.json).
//
//  No community Tsakhur layout exists: Agisight/ios-system-keyboard has no
//  layout/tkr and Agisight/rf-keyboard-corpora no data/tkr (commits 86e000a
//  and cd7a94e), not even a stub or a letter count.
//
//  The two-character letters of the alphabet are typed with the plain keys
//  (г + ъ, к + Ӏ, а + Ӏ …) and are also offered as long-press options that
//  insert both characters at once. Rows are written once, in lowercase;
//  the engine derives the shift layer (first letter: «кӀ» → «КӀ», «гъ» →
//  «Гъ») and Caps Lock (all letters: «ГЪ»).
//
//  Product data: the engine reads it only through
//  `KeyboardDefinition.current.layout` (see TsakhurDefinition.swift).
//

import Foundation
import GeneralKeyboard

extension LayoutStyle {
    /// The one Tsakhur layout. Persisted raw value; never rename.
    static let standard = LayoutStyle(rawValue: "standard")
}

enum TsakhurLayout {

    /// Ӏ U+04C0 CYRILLIC LETTER PALOCHKA: what the key shows and inserts.
    /// Never Latin I, the digit 1 or lowercase l.
    static let palochka = "\u{04C0}"

    /// ʼ U+02BC MODIFIER LETTER APOSTROPHE, the palatalization mark
    /// (TsakhurDefinition.palatalizationMark). Never the ASCII apostrophe,
    /// which ends a word.
    static let mark = "\u{02BC}"

    static let capabilities = LayoutCapabilities(
        styles: [standard],
        defaultStyle: .standard,
        // One style: the engine hides the selector and the quick menu.
        showsStyleSelector: false,
        persistenceKey: "layoutStyle",
        quickSwitchOnSettingsLongPress: false,
        // iPhone portrait on Apple's native keyboard grid (pixel-snapped
        // cells, native bottom-row proportions, native panel height), as
        // approved for Lezgi, Dargwa, Kumyk, Tabasaran, Lak and Aghul
        gridModel: .nativeCells
    )

    static let standard = LayoutStyleSpec(
        id: .standard,
        letterRows: letterRows,
        numberRows: numberRows,
        symbolRows: symbolRows,
        callouts: callouts,
        metrics: metrics,
        settingsTitle: "Стандартная",
        settingsSubtitle: "Русская раскладка, ъ на месте щ, Ӏ на месте э"
    )

    /// Three letter rows and the geometry the sibling keyboards ship with.
    static let metrics = KeyboardLayout.Metrics(totalHeight: 250, keyHeight: 43, rowSpacing: 11,
                                                emojiRows: 5, emojiCellHeight: 33)

    // MARK: - Letter rows

    static let letterRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","ъ","з","х"].map { .character($0) },        // 11 keys, ъ on щ's key
        ["ф","ы","в","а","п","р","о","л","д","ж",palochka].map { .character($0) },   // 11 keys, Ӏ on э's key
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) }     // 9 keys, as Russian
            + [.backspace],
    ]

    // MARK: - Number page (the standard Russian iOS set)

    static let numberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        [.symbols] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Symbol page (the standard Russian iOS set)

    static let symbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","$","€","¥","•"].map { .character($0) },
        [.numbers] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Long-press callouts
    // Keys are lowercase; the popup puts the base key first and the shift
    // state is applied to every option. An option is inserted as a whole
    // string («кӀ» = к + palochka U+04C0, two characters).

    /// The seventeen two-character letters of the Tsakhur alphabet of 1990
    /// (АӀ ГӀ Гъ Гь Дж КӀ Къ Кь ОӀ ПӀ ТӀ УӀ Хъ Хь ЦӀ ЧӀ ЫӀ) under their
    /// first letter. Where a key has several, they are in the order of
    /// their frequency in the newspaper sample (per 100 words: гь 11.4,
    /// гъ 5.9, гӀ 0.04; къ 4.1, кӀ 3.0, кь 1.9; хъ 8.4, хь 5.7).
    ///
    /// «лʼ» is not a letter of the alphabet but the commonest use of the
    /// palatalization mark: 712 of its 764 occurrences in the sample follow
    /// «л» («йигъылʼ», «вахталʼ»), 3.5 per 100 words.
    ///
    /// Doubled letters are typed by tapping the key twice: the long vowels
    /// («аа», «ее», «оо») and the doubled consonants («лл», «кк», «хх»).
    /// «хӀ» and the vowels «аь», «оь» of the IDS word list are not letters
    /// of the alphabet and have no option; they are typed key by key.
    static let digraphCallouts: [String: [String]] = [
        "а": ["а" + palochka],
        "г": ["гь", "гъ", "г" + palochka],
        "д": ["дж"],
        "к": ["къ", "к" + palochka, "кь"],
        "л": ["л" + mark],
        "о": ["о" + palochka],
        "п": ["п" + palochka],
        "т": ["т" + palochka],
        "у": ["у" + palochka],
        "х": ["хъ", "хь"],
        "ц": ["ц" + palochka],
        "ч": ["ч" + palochka],
        "ы": ["ы" + palochka],
    ]

    /// The three Russian letters without a key, each where a Russian typist
    /// looks for it: ё under е and щ under ш as on the Russian keyboard, э
    /// on the key that took its place. The palatalization mark is under the
    /// soft sign: it marks a soft consonant where «ь» cannot, because «гь»,
    /// «кь» and «хь» are letters of their own.
    static let letterCallouts: [String: [String]] = [
        "е": ["ё"],
        "ш": ["щ"],
        palochka: ["э"],
        "ь": [mark],
    ]

    /// The symbol alternates of the Russian iOS keyboard (as the sibling
    /// keyboards; the quote alternates sit on this layout's ' and " keys).
    static let symbolCallouts: [String: [String]] = [
        "0": ["°"],
        "₽": ["$", "€", "£", "¥", "￦"],
        "#": ["№"],
        ".": ["…"],
        "%": ["‰", "∞"],
        "=": ["≠", "≈"],
        "-": ["•", "–", "—"],
        "/": ["\\"],
        "&": ["§"],
        "?": ["¿"],
        "!": ["¡"],
        "'": ["’", "‘", "`"],
        "\"": ["”", "“", "„", "»", "«"],
    ]

    static let callouts: [String: [String]] = digraphCallouts
        .merging(letterCallouts) { first, _ in first }
        .merging(symbolCallouts) { first, _ in first }
}
