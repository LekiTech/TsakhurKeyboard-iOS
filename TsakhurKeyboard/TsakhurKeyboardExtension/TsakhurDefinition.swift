//
//  TsakhurDefinition.swift
//  TsakhurKeyboardExtension
//
//  The Tsakhur keyboard as a KeyboardDefinition: everything Tsakhur-specific
//  the General Keyboard engine uses, assembled in one value. The layout
//  lives in TsakhurLayout.swift, strings and key names in
//  TsakhurStrings.swift.
//

import Foundation
import GeneralKeyboard

enum TsakhurDefinition {

    /// ʼ U+02BC MODIFIER LETTER APOSTROPHE, the palatalization mark of
    /// Tsakhur spelling: «йигъылʼ», «мизʼ», «кӀылʼна», «гьелʼбедти». It
    /// follows a consonant (л in nine cases of ten) and belongs to the word.
    /// The newspaper «Нур» prints it as ' or ’, the Tsakhur word list of the
    /// Intercontinental Dictionary Series as ʼ. The keyboard types U+02BC:
    /// it is a letter in Unicode, so the keyboard and the host app both
    /// keep it inside the word (a typographic ’ at the end of a word reads
    /// as a closing quote). docs/LAYOUT.md, "The palatalization mark".
    static let palatalizationMark: Character = "\u{02BC}"

    /// Tsakhur Cyrillic, version 1: the canonical form of the bundled
    /// dictionary (scripts/build_dictionary.py mirrors it) and of learned
    /// words.
    ///
    /// It is the built-in Dagestanian Cyrillic profile with two additions:
    ///
    /// * the palatalization mark extends the consonant before it, like the
    ///   signs and the palochka do («лʼ» is one letter, as «кӀ» and «гъ»
    ///   are), so «улʼ» and «едʼ» are two-letter words the keyboard may
    ///   store and learn;
    /// * the other apostrophes a text may carry inside a Cyrillic word, ’
    ///   U+2019, ‘ U+2018 and the grave accent, are read as that mark, so a
    ///   word typed or pasted with one of them is the same word. The ASCII
    ///   ' ends a word in every General Keyboard product and stays a
    ///   separator here.
    ///
    /// In Tsakhur the palochka never stands alone: after к п т ц ч г it
    /// makes a consonant («кӀ»), after а о у ы a pharyngealized vowel
    /// («аӀ»). It is a digraph tail, as in the built-in profile.
    ///
    /// Everything else is the built-in rule set: the lookup palochka is ӏ
    /// U+04CF, and a Latin I, l or i, the Ukrainian І and the capital Ӏ
    /// inside a Cyrillic token are read as it.
    ///
    /// Identity is (id, version). Changing a rule means a new version, a
    /// dictionary rebuild and a sweep of learned data.
    static let normalization = NormalizationProfile(
        id: "tsakhur-cyrillic",
        version: 1,
        repairScripts: NormalizationProfile.dagestanianCyrillicV1.repairScripts,
        palochka: NormalizationProfile.dagestanianCyrillicV1.palochka,
        palochkaLookalikes: NormalizationProfile.dagestanianCyrillicV1.palochkaLookalikes,
        homoglyphs: NormalizationProfile.dagestanianCyrillicV1.homoglyphs.merging([
            "\u{2019}": palatalizationMark,
            "\u{2018}": palatalizationMark,
            "`": palatalizationMark,
        ]) { builtIn, _ in builtIn },
        rejectsASCIILetters: true,
        digraphTails: NormalizationProfile.dagestanianCyrillicV1.digraphTails
            .union([palatalizationMark])   // ӏ ь ъ ʼ
    )

    static let definition = KeyboardDefinition(
        // Stable identity: the extension's App Store bundle identifier.
        // Never reused for a different definition.
        id: "org.lekitech.tsakhurkeyboard.TsakhurKeyboardExtension",
        data: LanguageData(
            appGroupID: TsakhurIdentity.appGroupID,
            // TsakhurKeyboardExtension/tsakhur_words.sqlite and
            // tsakhur_bigrams.sqlite, built by scripts/build_dictionary.py
            wordsArtifact: "tsakhur_words",
            bigramsArtifact: "tsakhur_bigrams",
            diagnosticsSubsystem: "TsakhurKeyboardExtension"
        ),
        layout: TsakhurLayout.capabilities,
        keys: TsakhurStrings.keys,
        text: TextConventions(
            // Everything the user sees and types carries the palochka
            // Ӏ (U+04C0); lookup keys and stored rows keep ӏ (U+04CF).
            visiblePalochka: "\u{04C0}",
            // Ӏ is category Lu but caseless by convention: «КӀ» is a
            // capitalized digraph, not an ALL-CAPS prefix. The mark has no
            // case at all: «Лʼ» is not ALL CAPS either.
            caseNeutral: ["\u{04C0}", "\u{04CF}", palatalizationMark]
            // The engine's default word separators apply. The mark is a
            // letter and is not among them; the ASCII apostrophe is.
        ),
        normalization: normalization,
        strings: TsakhurStrings.strings,
        emojiCategoryTitles: TsakhurStrings.emojiCategoryTitles
    )
}
