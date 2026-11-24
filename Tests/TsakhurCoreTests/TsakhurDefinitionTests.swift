//
//  TsakhurDefinitionTests.swift
//  TsakhurCoreTests
//
//  The Tsakhur KeyboardDefinition: its own identity (never another
//  product's), the persisted contract, the Tsakhur Cyrillic profile (the
//  Dagestanian rules plus the palatalization mark ʼ U+02BC), the palochka
//  convention (Ӏ U+04C0 shown and typed, ӏ U+04CF as the lookup key), the
//  engine's default word separators, and the project's
//  two-target, two-identity setup (Debug for the developer's team, Release
//  for distribution).
//

import XCTest
import UIKit
@testable import TsakhurCore
@testable import GeneralKeyboard

final class TsakhurDefinitionTests: TsakhurTestCase {

    private var d: KeyboardDefinition { KeyboardDefinition.current }

    func testIdentityAndArtifacts() {
        XCTAssertEqual(d.validationErrors(), [])
        XCTAssertEqual(d.id, "org.lekitech.tsakhurkeyboard.TsakhurKeyboardExtension")
        XCTAssertEqual(TsakhurIdentity.releaseAppGroupID, "group.org.lekitech.tsakhurkeyboard")
        XCTAssertEqual(TsakhurIdentity.debugAppGroupID, "group.org.lekitech.tsakhurkeyboard.dev")
        // Tests build in Debug
        XCTAssertEqual(d.data.appGroupID, TsakhurIdentity.debugAppGroupID)
        XCTAssertEqual(WordSuggestions.artifactName, "tsakhur_words")
        XCTAssertEqual(StaticBigrams.artifactName, "tsakhur_bigrams")
        XCTAssertEqual(d.data.diagnosticsSubsystem, "TsakhurKeyboardExtension")
    }

    func testNeverReusesAnotherProductsIdentity() {
        let taken = ["lezgi", "avar", "dargwa", "kumyk", "tabasaran", "lakkeyboard", "aghul", "rutul", "vadivian",
                     "generalkeyboard", "reference"]
        for value in [d.id, d.data.appGroupID, TsakhurIdentity.releaseAppGroupID,
                      d.data.wordsArtifact, d.data.bigramsArtifact] {
            for other in taken {
                XCTAssertFalse(value.lowercased().contains(other), "\(value) contains \(other)")
            }
        }
    }

    // MARK: - Normalization and the palochka

    /// Tsakhur has its own profile: the built-in Dagestanian Cyrillic rules
    /// and the palatalization mark. The mark extends the consonant before
    /// it («лʼ» is one letter, like «кӀ» and «гъ»), and the typographic
    /// apostrophes are read as it.
    func testUsesItsOwnProfileWithThePalatalizationMark() {
        let builtIn = NormalizationProfile.dagestanianCyrillicV1
        XCTAssertEqual(d.normalization, TsakhurDefinition.normalization)
        XCTAssertNotEqual(d.normalization, builtIn)
        XCTAssertEqual(d.normalization.id, "tsakhur-cyrillic")
        XCTAssertEqual(Normalization.version, 1)
        XCTAssertEqual(Normalization.palochka, Tsakhur.lookup)
        XCTAssertEqual(TsakhurDefinition.palatalizationMark, Tsakhur.mark)
        XCTAssertEqual(Tsakhur.mark.unicodeScalars.map(\.value), [0x02BC])
        XCTAssertTrue(Tsakhur.mark.isLetter)
        XCTAssertEqual(d.normalization.digraphTails, [Tsakhur.lookup, "ь", "ъ", Tsakhur.mark])
        XCTAssertEqual(d.normalization.digraphTails.subtracting(builtIn.digraphTails), [Tsakhur.mark])
        XCTAssertEqual(d.normalization.repairScripts, builtIn.repairScripts)
        XCTAssertEqual(d.normalization.palochkaLookalikes, builtIn.palochkaLookalikes)
        var homoglyphs = builtIn.homoglyphs
        for apostrophe: Character in ["\u{2019}", "\u{2018}", "`"] { homoglyphs[apostrophe] = Tsakhur.mark }
        XCTAssertEqual(d.normalization.homoglyphs, homoglyphs)
        XCTAssertEqual(d.normalization.rejectsASCIILetters, builtIn.rejectsASCIILetters)
        XCTAssertEqual(d.text.visiblePalochka, Tsakhur.visible)
        XCTAssertEqual(d.text.caseNeutral, [Tsakhur.visible, Tsakhur.lookup, Tsakhur.mark])
    }

    /// One lookup key however the palochka was written: Ӏ U+04C0, ӏ U+04CF,
    /// or the Latin I, l and Ukrainian І that other keyboards, the
    /// newspaper «Нур» and the IDS word list produce.
    func testCanonicalFormOfTsakhurWords() {
        XCTAssertEqual(Normalization.canonical("К\u{04C0}ыл\u{02BC}на"), "к\u{04CF}ыл\u{02BC}на")
        XCTAssertEqual(Normalization.canonical("кIыл\u{02BC}на"), "к\u{04CF}ыл\u{02BC}на")
        XCTAssertEqual(Normalization.canonical("кlыл\u{02BC}на"), "к\u{04CF}ыл\u{02BC}на")
        XCTAssertEqual(Normalization.canonical("к\u{0406}ыл\u{02BC}на"), "к\u{04CF}ыл\u{02BC}на")
        XCTAssertEqual(Normalization.canonical("  А\u{04C0}К\u{04C0}ОЛ\u{02BC}\n"), "а\u{04CF}к\u{04CF}ол\u{02BC}")
        XCTAssertEqual(Normalization.canonical("О\u{04C0}лка"), "о\u{04CF}лка")
        XCTAssertEqual(Normalization.canonical("ЦIаIхна"), "ц\u{04CF}а\u{04CF}хна")
        // NFC: «й» typed as и plus a combining breve, the form that cost
        // v0 every word with «й»
        XCTAssertEqual(Normalization.canonical("кьадалии\u{0306}"), "кьадалий")
        // Latin twins inside a Cyrillic word are repaired (х, а here)
        XCTAssertEqual(Normalization.canonical("xaв"), "хав")
        // The digit 1 is not a palochka: such a token is refused, not repaired
        XCTAssertFalse(Normalization.isValidToken(Normalization.canonical("к1ыл")))
        for word in ["к\u{04CF}ыл\u{02BC}на", "ул\u{02BC}", "ед\u{02BC}", "а\u{04CF}к\u{04CF}ол\u{02BC}", "йигъ",
                     "о\u{04CF}лка", "дюнйе", "баттагъ", "гьач\u{04CF}иеъас", "цык-цык"] {
            XCTAssertTrue(Normalization.isCanonical(word), word)
            XCTAssertTrue(Normalization.isValidToken(word), word)
        }
        // What the user sees again carries U+04C0
        XCTAssertEqual(d.text.visibleForm("к\u{04CF}ыл\u{02BC}на", canonicalPalochka: Normalization.palochka),
                       "к\u{04C0}ыл\u{02BC}на")
        XCTAssertEqual(d.text.visibleForm("о\u{04CF}лка", canonicalPalochka: Normalization.palochka), "о\u{04C0}лка")
    }

    /// The palatalization mark has one stored form, ʼ U+02BC. The
    /// typographic apostrophes and the grave accent inside a Cyrillic word
    /// are read as it; the mark is never changed into anything else.
    func testThePalatalizationMarkHasOneLookupForm() {
        let word = "йигъыл\u{02BC}"
        XCTAssertEqual(Normalization.canonical("Йигъыл\u{02BC}"), word)
        XCTAssertEqual(Normalization.canonical("йигъыл\u{2019}"), word)
        XCTAssertEqual(Normalization.canonical("йигъыл\u{2018}"), word)
        XCTAssertEqual(Normalization.canonical("йигъыл`"), word)
        XCTAssertEqual(Normalization.canonical("к\u{04C0}ыл\u{2019}на"), "к\u{04CF}ыл\u{02BC}на")
        XCTAssertTrue(Normalization.isCanonical(word))
        XCTAssertFalse(Normalization.isCanonical("йигъыл\u{2019}"))
        // Not a soft sign: «гь», «кь» and «хь» are other letters
        XCTAssertNotEqual(Normalization.canonical("кок\u{02BC}"), "кокь")
        // Outside a Cyrillic word nothing is repaired
        XCTAssertEqual(Normalization.canonical("don\u{2019}t"), "don\u{2019}t")
        // Uppercasing a word for Caps Lock leaves the mark alone
        XCTAssertEqual("хыл\u{02BC}".uppercased(), "ХЫЛ\u{02BC}")
    }

    /// «ӏ», «ъ», «ь» and the mark extend the letter before them, so a lone
    /// «гъ», «кӀ», «аӀ» or «лʼ» is one letter and never learned as a word.
    func testLetterCount() {
        for digraph in ["гъ", "гь", "къ", "кь", "хъ", "хь", "к\u{04CF}", "ц\u{04CF}", "а\u{04CF}", "ы\u{04CF}",
                        "л\u{02BC}", "к\u{02BC}"] {
            XCTAssertEqual(Normalization.letterCount(digraph), 1, digraph)
            XCTAssertFalse(Normalization.isValidToken(digraph), digraph)
        }
        XCTAssertEqual(Normalization.letterCount("\u{02BC}"), 0)
        XCTAssertEqual(Normalization.letterCount("ул\u{02BC}"), 2)                    // у лʼ
        XCTAssertTrue(Normalization.isValidToken("ул\u{02BC}"))
        XCTAssertTrue(Normalization.isValidToken("ед\u{02BC}"))
        XCTAssertEqual(Normalization.letterCount("к\u{04CF}ыл\u{02BC}на"), 5)         // кӏ ы лʼ н а
        XCTAssertEqual(Normalization.letterCount("а\u{04CF}к\u{04CF}ол\u{02BC}"), 4)  // аӏ кӏ о лʼ
        XCTAssertEqual(Normalization.letterCount("баттагъ"), 6)                       // a doubled consonant is two characters
        XCTAssertEqual(Normalization.letterCount("гьаъас"), 4)                        // гь аъ а с: «ъ» after a vowel is a tail too
        XCTAssertTrue(Normalization.isValidToken("ц\u{04CF}а"))
        XCTAssertFalse(Normalization.isValidToken("у\u{04CF}"))
    }

    // MARK: - Word separators

    /// The engine's default separators apply unchanged. The palatalization
    /// mark is a letter and stays inside the word, as do the typographic
    /// apostrophes that are read as it; the ASCII apostrophe ends a word
    /// as in every General Keyboard product.
    func testWordSeparatorsAreTheEngineDefaults() {
        let separators = d.text.wordSeparators
        XCTAssertEqual(separators, TextConventions.defaultWordSeparators)
        for scalar in " \n.,!?;:\"'()[]{}—–-".unicodeScalars {
            XCTAssertTrue(separators.contains(scalar))
        }
        for scalar in "аяъьщ\u{04C0}\u{04CF}\u{02BC}\u{2019}".unicodeScalars {
            XCTAssertFalse(separators.contains(scalar))
        }
    }

    // MARK: - Layout capabilities and strings

    func testLayoutCapabilities() {
        XCTAssertEqual(d.layout.styles.map(\.id.rawValue), ["standard"])
        XCTAssertEqual(d.layout.defaultStyle.rawValue, "standard")
        XCTAssertEqual(d.layout.persistenceKey, "layoutStyle")
        XCTAssertFalse(d.layout.showsSelector)
        XCTAssertFalse(d.layout.showsQuickSwitch)
        XCTAssertEqual(d.layout.gridModel, .nativeCells)
        XCTAssertEqual(d.layout.resolve(nil).rawValue, "standard")
        XCTAssertEqual(d.layout.resolve("classic").rawValue, "standard")
        XCTAssertEqual(d.layout.spec(for: .standard).bottomRowAfterSpace, [])
    }

    /// Everything the user reads or types carries Ӏ U+04C0, never the
    /// lookup form ӏ U+04CF and never a Latin I or l standing in for it.
    func testUserFacingTextUsesTheVisiblePalochka() {
        let s = d.strings
        var texts: [String] = [
            s.deleteWordQuestion("кӀылʼна"), s.no, s.delete, s.emojiRecents, s.back, s.close,
            s.settingsCaption, s.settingsTitle, s.pageInput, s.pageTheme, s.pageDictionary,
            s.pageAbout, s.sectionLayout, s.sectionSuggestions, s.sectionKeys, s.sectionLearning,
            s.sectionLongPress, s.sectionTheme, s.wordSuggestions, s.nextWordSuggestion,
            s.autoSpace, s.doubleSpacePeriod, s.spaceCursor, s.spaceCornerToggle,
            s.spaceCornerToggleSubtitle, s.learnFast, s.learnNormal, s.learnSlow, s.learnUses(3),
            s.calloutShort, s.calloutNormal, s.calloutLong, s.calloutDuration(0.3), s.themeSystem,
            s.themeLight, s.themeDark, s.learnedWordsCaption, s.noWordsYet, s.deleteAll,
            s.deleteAllQuestion, s.aboutInitial, s.aboutTitle, s.aboutByline("1.0.0"),
            d.keys.space, d.keys.spaceCornerLabel, d.keys.keyboardName, d.keys.lettersKey,
            d.keys.lettersKeyShifted, d.keys.emojiPageLettersKey,
        ]
        texts += d.keys.returnLabels.values
        texts += d.emojiCategoryTitles.values
        let spec = d.layout.spec(for: .standard)
        texts += [spec.settingsTitle, spec.settingsSubtitle]
        var letterTexts: [String] = []
        for row in spec.letterRows {
            for case .character(let c) in row { letterTexts.append(c) }
        }
        for (key, alternates) in spec.callouts where key.first!.isLetter { letterTexts += [key] + alternates }
        for text in texts + letterTexts {
            XCTAssertFalse(text.contains(Tsakhur.lookup), "\(text) shows the lookup palochka U+04CF")
        }
        // No Latin letter on a letter key or in a letter's long press
        for text in letterTexts {
            XCTAssertFalse(text.contains(where: { $0.isASCII && $0.isLetter }), "\(text) has a Latin letter")
        }
        XCTAssertEqual(d.keys.keyboardName, "Ц\u{04C0}а\u{04C0}хна миз")
        XCTAssertEqual(d.keys.spaceCornerLabel, "Ц\u{04C0}А\u{04C0}Х")
        XCTAssertEqual(s.spaceCornerToggle, "«ц\u{04C0}а\u{04C0}х» на пробеле")
        XCTAssertEqual(s.settingsCaption, "ЦАХУРСКАЯ КЛАВИАТУРА")
        XCTAssertEqual(s.aboutTitle, "Цахурская клавиатура")
        XCTAssertEqual(s.aboutInitial, "Ц")
        XCTAssertEqual(s.sectionLongPress, "Долгое нажатие (к\u{04C0}, хь, ё…)")
        // The palochka key itself
        XCTAssertEqual(spec.letterRows[1][10], .character(String(Tsakhur.visible)))
        // The palatalization mark is the letter U+02BC wherever it is offered
        XCTAssertEqual(spec.callouts["ь"], [String(Tsakhur.mark)])
        XCTAssertEqual(spec.callouts["л"], ["л" + String(Tsakhur.mark)])
    }

    /// Every two-character long-press option whose second character is a
    /// digraph tail of the profile (the palochka, a sign or the mark) is one
    /// letter for the engine; «дж» is two.
    func testLetterCountOfEveryTwoCharacterCallout() {
        var one = 0, two = 0
        for (_, alternates) in d.layout.spec(for: .standard).callouts {
            for alt in alternates where alt.count == 2 && alt.first!.isLetter {
                let canonical = Normalization.canonical(alt)
                if d.normalization.digraphTails.contains(canonical.last!) {
                    XCTAssertEqual(Normalization.letterCount(canonical), 1, alt)
                    one += 1
                } else {
                    XCTAssertEqual(canonical, "дж", alt)
                    XCTAssertEqual(Normalization.letterCount(canonical), 2, alt)
                    two += 1
                }
            }
        }
        XCTAssertEqual(one, 17)   // аӀ гь гъ гӀ къ кӀ кь лʼ оӀ пӀ тӀ уӀ хъ хь цӀ чӀ ыӀ
        XCTAssertEqual(two, 1)    // дж
    }

    func testRussianFallbackFormatting() {
        let s = d.strings
        XCTAssertEqual(s.learnUses(1), "1 раз")
        XCTAssertEqual(s.learnUses(3), "3 раза")
        XCTAssertEqual(s.learnUses(5), "5 раз")
        XCTAssertEqual(s.learnUses(12), "12 раз")
        XCTAssertEqual(s.learnUses(22), "22 раза")
        XCTAssertEqual(s.calloutDuration(0.2), "0,2 с")
        XCTAssertEqual(s.calloutDuration(0.45), "0,45 с")
        XCTAssertEqual(s.aboutByline("1.0.0"), "Версия 1.0.0 · LekiTech")
    }

    // MARK: - Project

    /// Two targets, no sticker or messenger targets; Debug signs with the
    /// developer's team under `.dev` identifiers, Release carries the App
    /// Store identifiers and no team (the distribution team adds its own).
    func testProjectTargetsAndSigning() throws {
        let pbx = try RepoPaths.text(RepoPaths.project)
        XCTAssertEqual(pbx.components(separatedBy: "isa = PBXNativeTarget;").count - 1, 2)
        XCTAssertEqual(pbx.components(separatedBy: "com.apple.product-type.application\"").count - 1, 1)
        XCTAssertEqual(pbx.components(separatedBy: "com.apple.product-type.app-extension\"").count - 1, 1)
        for banned in ["sticker", "Sticker", "messages", "telegram", "whatsapp", "instagram",
                       "Lezgi", "lezgi", "Avar", "avar", "Dargwa", "dargwa", "Kumyk", "kumyk",
                       "Tabasaran", "tabasaran", "LakKeyboard", "lakkeyboard", "Aghul", "aghul",
                       "Rutul", "rutul", "vadivian"] {
            XCTAssertFalse(pbx.contains(banned), "project mentions \(banned)")
        }
        let bundleIDs = Set(pbx.matches(of: /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/).map { String($0.1) })
        XCTAssertEqual(bundleIDs, [
            "org.lekitech.tsakhurkeyboard.dev", "org.lekitech.tsakhurkeyboard.dev.TsakhurKeyboardExtension",
            "org.lekitech.tsakhurkeyboard", "org.lekitech.tsakhurkeyboard.TsakhurKeyboardExtension",
        ])
        let groups = Set(pbx.matches(of: /TSAKHUR_APP_GROUP_ID = ([^;]+);/).map { String($0.1) })
        XCTAssertEqual(groups, [TsakhurIdentity.debugAppGroupID, TsakhurIdentity.releaseAppGroupID])
        let teams = pbx.matches(of: /\bDEVELOPMENT_TEAM = ([^;]+);/).map { String($0.1) }
        XCTAssertEqual(teams.sorted(), ["\"\"", "\"\"", "RC94H8KQYA", "RC94H8KQYA"])
        XCTAssertTrue(pbx.contains("relativePath = \"../../GeneralKeyboard-iOS\";"))

        for file in ["TsakhurKeyboard/TsakhurKeyboard/TsakhurKeyboard.entitlements",
                     "TsakhurKeyboard/TsakhurKeyboardExtension/TsakhurKeyboardExtension.entitlements"] {
            let plist = try RepoPaths.text(RepoPaths.root.appendingPathComponent(file))
            XCTAssertTrue(plist.contains("<string>$(TSAKHUR_APP_GROUP_ID)</string>"), file)
        }
        let info = try RepoPaths.text(RepoPaths.extensionFolder.appendingPathComponent("Info.plist"))
        XCTAssertTrue(info.contains("<string>tkr</string>"))
        XCTAssertTrue(info.contains("<key>RequestsOpenAccess</key>\n\t\t\t<false/>"))
    }
}
