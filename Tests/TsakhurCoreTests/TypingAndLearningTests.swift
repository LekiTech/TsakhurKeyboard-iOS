//
//  TypingAndLearningTests.swift
//  TsakhurCoreTests
//
//  The keyboard model built exactly as the extension builds it (its own
//  UserDefaults, its own learned store), fed through a mock host: the keys
//  and the long-press options insert Tsakhur letters and digraphs with
//  the palochka Ӏ U+04C0 in lowercase, title case and uppercase, the
//  palatalization mark ʼ U+02BC stays inside its word, typed and picked
//  words are learned under the lookup form and come back in the visible
//  one, settings persist, the default learning speed is Normal. The bundled
//  artifacts are not in the test bundle, so the model's dictionary tier is
//  empty here; the dictionary itself is covered by DictionaryTests. Every
//  word is a real word of the Tsakhur dictionary.
//

import XCTest
import UIKit
@testable import TsakhurCore
@testable import GeneralKeyboard

final class TypingAndLearningTests: TsakhurTestCase {

    private static let persistedKeys = [
        "layoutStyle", "recentEmojis",
        "set_wordSuggestions", "set_nextWordSuggestions", "set_autoSpaceAfterSuggestion",
        "set_doubleSpacePeriod", "set_spaceCursor", "set_spaceLabel",
        "set_learnSpeed", "set_calloutDelay", "set_theme",
    ]

    override func setUp() {
        super.setUp()
        for key in Self.persistedKeys { UserDefaults.standard.removeObject(forKey: key) }
        // Empty the learned store IN PLACE; never delete learned.sqlite
        // while a model may still hold it open.
        LearnedWords()?.reset()
        // These tests follow a word from its first use, so they run with
        // Fast selected, the way a user picks it in the settings panel.
        // The default (Normal, three uses) has its own tests under
        // "Learning speed", which start without a stored choice.
        UserDefaults.standard.set("fast", forKey: "set_learnSpeed")
    }

    @MainActor
    private func type(_ text: String, into model: KeyboardModel, proxy: MockTextDocumentProxy) {
        for ch in text {
            model.handleKey(ch == " " ? .space : .character(String(ch)), proxy: proxy)
            model.updateSuggestions(proxy: proxy)
        }
    }

    /// What the keyboard does when a suggestion is tapped: the typed
    /// prefix is replaced by the word and a space, and the model is told.
    @MainActor
    private func pick(_ word: String, in model: KeyboardModel, proxy: MockTextDocumentProxy) {
        let previous = model.previousWord(proxy: proxy)
        for _ in 0..<model.wordPrefix(proxy: proxy).count { proxy.deleteBackward() }
        proxy.insertText(word + " ")
        model.recordPickedSuggestion(word, previous: previous, insertedSpace: true)
        model.updateSuggestions(proxy: proxy)
    }

    private func scalars(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    // MARK: - Rows

    @MainActor
    func testKeyboardShowsThreeLetterRowsAndTheBottomRow() {
        let model = KeyboardModel()
        let rows = model.rows(needsGlobe: true)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].count, 11)
        XCTAssertEqual(rows[1].count, 11)
        XCTAssertEqual(rows[2].count, 11)   // shift, nine letters, backspace
        XCTAssertEqual(rows[0][8], .character("ъ"))
        XCTAssertEqual(rows[1][1], .character("ы"))
        XCTAssertEqual(rows[1][10], .character("\u{04C0}"))
        XCTAssertEqual(rows[3], [.numbers, .settings, .emoji, .globe, .space, .return])
        XCTAssertEqual(model.rows(needsGlobe: false)[3], [.numbers, .settings, .emoji, .space, .return])
        XCTAssertEqual(model.layoutStyle, .standard)
    }

    // MARK: - Keys and digraphs

    @MainActor
    func testEveryLetterKeyInsertsItsLetter() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let letters = "йцукенгшъзхфывапролдж\u{04C0}ячсмитьбю"
        for ch in letters { model.handleKey(.character(String(ch)), proxy: proxy) }
        XCTAssertEqual(proxy.before, letters)
        XCTAssertEqual(proxy.before.unicodeScalars.count, 31)
        XCTAssertTrue(Tsakhur.isTsakhurText(proxy.before))
    }

    /// The palochka key inserts U+04C0 whatever the shift state: the letter
    /// is caseless, and the lookup form U+04CF never reaches the text.
    @MainActor
    func testPalochkaKeyInsertsU04C0() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before), [0x04C0])
        model.shiftState = .once
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        model.shiftState = .capsLock
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before), [0x04C0, 0x04C0, 0x04C0])
        XCTAssertFalse(proxy.before.contains("\u{04CF}"))
        XCTAssertFalse(proxy.before.contains("I"))
        // Even a key that carried the lookup form would insert the visible one
        model.shiftState = .off
        model.handleKey(.character("\u{04CF}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before).last, 0x04C0)
        model.shiftState = .off
    }

    /// The seventeen two-character letters and the doubled ones, typed key by key.
    @MainActor
    func testDigraphsTypedKeyByKey() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let text = (Tsakhur.digraphs + Tsakhur.doubled).joined(separator: " ")
        type(text, into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, text)
        XCTAssertEqual(scalars("кӀ"), [0x043A, 0x04C0])
        XCTAssertEqual(scalars("аӀ"), [0x0430, 0x04C0])
        XCTAssertTrue(Tsakhur.isTsakhurText(proxy.before.replacingOccurrences(of: " ", with: "")))
    }

    /// A long-press option inserts the complete digraph; the result is the
    /// same string as typing its two keys.
    @MainActor
    func testLongPressOptionsInsertWholeDigraphs() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let spec = KeyboardDefinition.current.layout.spec(for: .standard)
        var options: [String] = []
        for key in ["а", "г", "д", "к", "л", "о", "п", "т", "у", "х", "ц", "ч", "ы", "е", "ш", "\u{04C0}", "ь"] {
            options += spec.callouts[key]!
        }
        XCTAssertEqual(options, ["аӀ", "гь", "гъ", "гӀ", "дж", "къ", "кӀ", "кь", "лʼ", "оӀ", "пӀ", "тӀ",
                                 "уӀ", "хъ", "хь", "цӀ", "чӀ", "ыӀ", "ё", "щ", "э", "ʼ"])
        for option in options { model.handleKey(.character(option), proxy: proxy) }
        XCTAssertEqual(proxy.before, "аӀгьгъгӀджкъкӀкьлʼоӀпӀтӀуӀхъхьцӀчӀыӀёщэʼ")
        XCTAssertEqual(proxy.before.unicodeScalars.count, 40)
        XCTAssertTrue(Tsakhur.isTsakhurText(proxy.before))
        XCTAssertFalse(proxy.before.contains("\u{04CF}"))
        XCTAssertFalse(proxy.before.contains("'"))

        let typed = MockTextDocumentProxy()
        for ch in "аӀгьгъгӀджкъкӀкьлʼоӀпӀтӀуӀхъхьцӀчӀыӀ" {
            model.handleKey(.character(String(ch)), proxy: typed)
        }
        XCTAssertTrue(proxy.before.hasPrefix(typed.before))
        XCTAssertEqual(Array(typed.before.unicodeScalars), Array(proxy.before.unicodeScalars.prefix(36)))
    }

    /// Shift capitalizes the first letter of a digraph («КӀ», «Хъ», «АӀ»),
    /// Caps Lock all of it («КӀ», «ХЪ», «АӀ»), for long-press options and
    /// plain keys alike. The palochka and the mark keep their one form.
    @MainActor
    func testShiftAndCapsLockOnDigraphs() {
        let model = KeyboardModel()
        let titleCase = ["аӀ": "АӀ", "гь": "Гь", "гъ": "Гъ", "гӀ": "ГӀ", "дж": "Дж", "къ": "Къ", "кӀ": "КӀ",
                         "кь": "Кь", "лʼ": "Лʼ", "оӀ": "ОӀ", "пӀ": "ПӀ", "тӀ": "ТӀ", "уӀ": "УӀ",
                         "хъ": "Хъ", "хь": "Хь", "цӀ": "ЦӀ", "чӀ": "ЧӀ", "ыӀ": "ЫӀ",
                         "ё": "Ё", "щ": "Щ", "э": "Э"]
        let upperCase = ["аӀ": "АӀ", "гь": "ГЬ", "гъ": "ГЪ", "гӀ": "ГӀ", "дж": "ДЖ", "къ": "КЪ", "кӀ": "КӀ",
                         "кь": "КЬ", "лʼ": "Лʼ", "оӀ": "ОӀ", "пӀ": "ПӀ", "тӀ": "ТӀ", "уӀ": "УӀ",
                         "хъ": "ХЪ", "хь": "ХЬ", "цӀ": "ЦӀ", "чӀ": "ЧӀ", "ыӀ": "ЫӀ",
                         "ё": "Ё", "щ": "Щ", "э": "Э"]
        XCTAssertEqual(titleCase.count, 21)
        for (option, expected) in titleCase {
            let proxy = MockTextDocumentProxy()
            model.shiftState = .once
            model.handleKey(.character(option), proxy: proxy)
            XCTAssertEqual(proxy.before, expected)
            XCTAssertEqual(model.shiftState, .off)
            XCTAssertFalse(proxy.before.contains("\u{04CF}"), expected)
            // The key label previews exactly what a tap inserts
            XCTAssertEqual(KeyboardLayout.label(for: .character(option), shifted: true, capsLock: false), expected)
        }
        for (option, expected) in upperCase {
            let proxy = MockTextDocumentProxy()
            model.shiftState = .capsLock
            model.handleKey(.character(option), proxy: proxy)
            XCTAssertEqual(proxy.before, expected)
            XCTAssertEqual(model.shiftState, .capsLock)
            XCTAssertFalse(proxy.before.contains("\u{04CF}"), expected)
            XCTAssertEqual(KeyboardLayout.label(for: .character(option), shifted: true, capsLock: true), expected)
        }
        // The mark alone has no capital
        for (shifted, capsLock) in [(false, false), (true, false), (true, true)] {
            XCTAssertEqual(KeyboardLayout.label(for: .character("\u{02BC}"), shifted: shifted, capsLock: capsLock),
                           "\u{02BC}")
        }
        // Key by key: Shift, ц, Ӏ, а, Ӏ, х → «ЦӀаӀх»; Caps Lock → «ЦӀАӀХ»
        let proxy = MockTextDocumentProxy()
        model.shiftState = .once
        type("цӀаӀх", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ЦӀаӀх")
        proxy.before = ""
        model.shiftState = .capsLock
        type("цӀаӀх", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ЦӀАӀХ")
        XCTAssertEqual(scalars(proxy.before), [0x0426, 0x04C0, 0x0410, 0x04C0, 0x0425])
        model.shiftState = .off
    }

    @MainActor
    func testSentenceStartShiftsAndSpaceBehaviour() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        XCTAssertEqual(model.shiftState, .once)   // new field: auto-capitalized
        type("кӀылʼна", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀылʼна")
        model.handleKey(.space, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀылʼна ")
        XCTAssertEqual(model.composedWord, "")
        // A long-press digraph at the start of a sentence is title case
        let fresh = MockTextDocumentProxy()
        let again = KeyboardModel()
        again.handleKey(.character("хь"), proxy: fresh)
        type("ад", into: again, proxy: fresh)
        XCTAssertEqual(fresh.before, "Хьад")
    }

    // MARK: - The palatalization mark

    /// The mark is typed as ʼ U+02BC and belongs to the word before the
    /// cursor: the word being typed includes it, in the middle and at the
    /// end. The ASCII apostrophe of the number page ends the word, as in
    /// every General Keyboard product.
    @MainActor
    func testTheMarkStaysInsideTheWordBeingTyped() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("йигъылʼ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "йигъылʼ")
        XCTAssertEqual(scalars(proxy.before).last, 0x02BC)
        XCTAssertEqual(model.wordPrefix(proxy: proxy), "йигъылʼ")
        type(" кӀылʼн", into: model, proxy: proxy)
        XCTAssertEqual(model.wordPrefix(proxy: proxy), "кӀылʼн")
        XCTAssertEqual(model.previousWord(proxy: proxy), "йигъылʼ")
        // The long-press option «лʼ» gives the same text as its two keys
        let pressed = MockTextDocumentProxy()
        let again = KeyboardModel()
        again.shiftState = .off
        type("йигъы", into: again, proxy: pressed)
        again.handleKey(.character("лʼ"), proxy: pressed)
        XCTAssertEqual(pressed.before, "йигъылʼ")
        // The ASCII apostrophe is a separator
        let plain = MockTextDocumentProxy(before: "йигъыл'")
        XCTAssertEqual(again.wordPrefix(proxy: plain), "")
    }

    /// A word with the mark is learned whole and suggested whole, with the
    /// mark it was typed with or with the apostrophe ’ that other keyboards
    /// and the newspaper use. Shift capitalizes its first letter only.
    @MainActor
    func testWordsWithTheMarkAreLearnedAndSuggested() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("хылʼ мизʼ хʼян ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords().sorted(), ["мизʼ", "хʼян", "хылʼ"])
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("хыл\u{02BC}"))
        XCTAssertTrue(store.isRecognized("хыл\u{2019}"))            // ’ from another keyboard
        XCTAssertTrue(store.isRecognized("ХЫЛ\u{02BC}"))
        XCTAssertFalse(store.isRecognized("хыл"))                   // another word
        XCTAssertEqual(store.topWords(limit: 5).sorted(), ["миз\u{02BC}", "х\u{02BC}ян", "хыл\u{02BC}"])
        // Mid-sentence
        type("хы", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["хы", "хылʼ"])
        // At the start of a sentence
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("хыл", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Хыл")
        XCTAssertTrue(model.suggestions.contains("Хылʼ"), "\(model.suggestions)")
        // «Хʼ» is a capital and a caseless mark, not an ALL-CAPS prefix
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("хʼ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Хʼ")
        XCTAssertTrue(model.suggestions.contains("Хʼян"), "\(model.suggestions)")
        XCTAssertFalse(model.suggestions.contains("ХʼЯН"), "\(model.suggestions)")
        // Caps Lock
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .capsLock
        type("хыл", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ХЫЛ")
        XCTAssertTrue(model.suggestions.contains("ХЫЛʼ"), "\(model.suggestions)")
        model.shiftState = .off
    }

    // MARK: - Learning

    /// Typed with the keyboard's Ӏ, stored under the lookup form, shown
    /// again with Ӏ.
    @MainActor
    func testTypedWordIsLearnedCanonicallyAndSuggestedVisibly() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀылʼна ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "кӀылʼна ")
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("к\u{04CF}ыл\u{02BC}на"))
        XCTAssertTrue(store.isRecognized("кӀылʼна"))
        XCTAssertTrue(store.isRecognized("КӀЫЛʼНА"))
        XCTAssertTrue(store.isRecognized("кIыл\u{2019}на"))         // Latin I and ’ from another keyboard
        XCTAssertEqual(store.topWords(limit: 5), ["к\u{04CF}ыл\u{02BC}на"])
        // Suggested back with the visible palochka while typing its prefix.
        // The bar leads with the typed prefix as a quoted literal (it is not
        // a word of its own), the learned word follows.
        type("кӀы", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["кӀы", "кӀылʼна"])
        XCTAssertFalse(model.suggestions.joined().contains("\u{04CF}"))
        XCTAssertTrue(model.isLearnedSuggestion("кӀылʼна"))
        XCTAssertEqual(model.savedWords(), ["кӀылʼна"])
    }

    /// A capitalized prefix capitalizes the suggestion's first letter only:
    /// «КӀ…» is a title-case digraph, not an all-caps prefix.
    @MainActor
    func testSuggestionFollowsTheCaseOfADigraphPrefix() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀылʼна хьунаще ", into: model, proxy: proxy)
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("кӀ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀ")
        XCTAssertTrue(model.suggestions.contains("КӀылʼна"), "\(model.suggestions)")
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("хьу", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Хьу")
        XCTAssertTrue(model.suggestions.contains("Хьунаще"), "\(model.suggestions)")
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .capsLock
        type("кӀы", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀЫ")
        XCTAssertTrue(model.suggestions.contains("КӀЫЛʼНА"), "\(model.suggestions)")
        model.shiftState = .off
    }

    /// Tapping a suggestion replaces the prefix with the whole word, with
    /// its digraphs and its mark intact, and adds the space.
    @MainActor
    func testAcceptedSuggestionInsertsTheWholeWord() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("аӀкӀолʼ ", into: model, proxy: proxy)
        type("аӀк", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["аӀк", "аӀкӀолʼ"])
        pick("аӀкӀолʼ", in: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "аӀкӀолʼ аӀкӀолʼ ")
        XCTAssertEqual(scalars(String(proxy.before.suffix(8))),
                       [0x0430, 0x04C0, 0x043A, 0x04C0, 0x043E, 0x043B, 0x02BC, 0x0020])
        XCTAssertEqual(model.composedWord, "")
        // The pick itself counts as a stronger use than typing
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("аӀкӀолʼ"))
        // Sentence punctuation right after a picked word swallows the
        // automatic space, also after a word that ends in the mark
        model.handleKey(.character("."), proxy: proxy)
        XCTAssertEqual(proxy.before, "аӀкӀолʼ аӀкӀолʼ.")
    }

    @MainActor
    func testLearnedWordsSurviveANewModel() {
        do {
            let model = KeyboardModel()
            let proxy = MockTextDocumentProxy()
            model.shiftState = .off
            type("оӀлка аӀкӀолʼ ", into: model, proxy: proxy)
        }
        // A new keyboard controller (new model, same container)
        let again = KeyboardModel()
        let proxy = MockTextDocumentProxy(before: "оӀлка ")
        again.shiftState = .off
        again.syncComposedWord(proxy: proxy)
        XCTAssertEqual(again.savedWords().sorted(), ["аӀкӀолʼ", "оӀлка"])
        type("аӀк", into: again, proxy: proxy)
        XCTAssertEqual(again.suggestions, ["аӀк", "аӀкӀолʼ"])
    }

    /// The bundled dictionary has few word pairs, so the next word mostly
    /// comes from what the user typed: a pair seen twice is predicted.
    @MainActor
    func testPersonalBigramPredictsTheNextWord() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        // A pair seen twice is confident enough to predict (minPairUses)
        type("цӀаӀхна миз ", into: model, proxy: proxy)
        type("цӀаӀхна миз ", into: model, proxy: proxy)
        // After the first word and a space, its learned follower leads the bar
        type("цӀаӀхна ", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions.first, "миз")
        // … and after a word that ends in the mark
        type("йигъылʼ сен ", into: model, proxy: proxy)
        type("йигъылʼ сен ", into: model, proxy: proxy)
        type("йигъылʼ ", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions.first, "сен")
    }

    @MainActor
    func testDeletingALearnedWordRemovesIt() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀылʼна хьунаще ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords().sorted(), ["кӀылʼна", "хьунаще"])
        // The list shows Ӏ; deleting by that visible form reaches the row
        model.deleteLearnedWord("кӀылʼна", proxy: proxy)
        XCTAssertEqual(model.savedWords(), ["хьунаще"])
        XCTAssertFalse(try XCTUnwrap(LearnedWords()).isRecognized("кӀылʼна"))
        model.resetLearnedWords(proxy: proxy)
        XCTAssertEqual(model.savedWords(), [])
        XCTAssertFalse(try XCTUnwrap(LearnedWords()).isRecognized("хьунаще"))
    }

    /// A lone letter is not a word, and the palochka, «ъ», «ь» and the
    /// mark only extend the letter before them («хъ», «гь», «кӀ», «аӀ»,
    /// «лʼ» are one letter each); the store refuses them.
    @MainActor
    func testSingleLettersAndLoneDigraphsAreNotLearned() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("хъ гь кӀ аӀ лʼ а ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [])
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertFalse(store.isRecognized("хъ"))
        XCTAssertFalse(store.isRecognized("кӀ"))
        XCTAssertFalse(store.isRecognized("лʼ"))
    }

    // MARK: - Settings

    @MainActor
    func testSettingsPersistAcrossModels() {
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")   // a fresh install
        let model = KeyboardModel()
        XCTAssertEqual(model.settings.learnSpeed, .normal)
        XCTAssertEqual(model.settings.theme, .system)
        model.updateSettings {
            $0.theme = .dark
            $0.learnSpeed = .conservative
            $0.calloutDelay = .long
            $0.nextWordSuggestions = false
        }
        let again = KeyboardModel()
        XCTAssertEqual(again.settings.theme, .dark)
        XCTAssertEqual(again.settings.learnSpeed, .conservative)
        XCTAssertEqual(again.settings.calloutDelay, .long)
        XCTAssertFalse(again.settings.nextWordSuggestions)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "set_theme"), "dark")
        XCTAssertEqual(model.layoutStyle, .standard)
    }

    // MARK: - Learning speed

    /// A fresh install has no stored learning speed and follows General
    /// Keyboard's default, Normal: a word is suggested after three uses.
    @MainActor
    func testFreshInstallLearnsAWordAfterThreeUses() {
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")
        let model = KeyboardModel()
        XCTAssertEqual(model.settings.learnSpeed, .normal)
        XCTAssertEqual(model.settings.learnSpeed.minUses, 3)
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀылʼна ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [], "1 of 3 uses")
        type("кӀылʼна ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [], "2 of 3 uses")
        type("кӀылʼна ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), ["кӀылʼна"])
        type("кӀы", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["кӀы", "кӀылʼна"])
        // Following the default stores nothing
        XCTAssertNil(UserDefaults.standard.object(forKey: "set_learnSpeed"))
    }

    /// A learning speed the user saved is kept: Fast stays Fast and Slow
    /// stays Slow, and words learned earlier are neither deleted nor reset.
    @MainActor
    func testSavedLearningSpeedAndLearnedWordsAreKept() throws {
        for (raw, speed) in [("fast", KeyboardSettings.LearnSpeed.fast), ("conservative", .conservative)] {
            UserDefaults.standard.set(raw, forKey: "set_learnSpeed")
            XCTAssertEqual(KeyboardModel().settings.learnSpeed, speed, raw)
            XCTAssertEqual(UserDefaults.standard.string(forKey: "set_learnSpeed"), raw)
        }
        // A word used once before the default was Normal, no stored choice
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")
        try XCTUnwrap(LearnedWords()).learn("кӀылʼна", previous: nil, picked: false)
        let model = KeyboardModel()
        XCTAssertEqual(model.savedWords(), [])
        XCTAssertTrue(try XCTUnwrap(LearnedWords()).isRecognized("кӀылʼна"), "the row and its count are still stored")
        model.updateSettings { $0.learnSpeed = .fast }
        XCTAssertEqual(model.savedWords(), ["кӀылʼна"])
    }
}
