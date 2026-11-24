//
//  TsakhurLayoutTests.swift
//  TsakhurCoreTests
//
//  TsakhurLayout.swift: the three letter rows, the two departures from the
//  Russian iOS layout (checked against the pinned transcription of that
//  layout, Fixtures/agisight/rus-3-rows.yaml), every long-press mapping,
//  the alphabet, and the evidence the design rests on: the letter counts
//  of the newspaper sample (docs/layout/nur_sample.json) and of the shipped
//  dictionary.
//

import XCTest
import SQLite3
import UIKit
@testable import TsakhurCore
@testable import GeneralKeyboard

final class TsakhurLayoutTests: TsakhurTestCase {

    private var spec: LayoutStyleSpec { KeyboardDefinition.current.layout.spec(for: .standard) }
    private let palochka = String(Tsakhur.visible)

    private func characters(_ row: [KeyCap]) -> [String] {
        row.compactMap { if case .character(let c) = $0 { return c } else { return nil } }
    }

    private var letterKeys: [String] { spec.letterRows.flatMap(characters) }

    // MARK: - Minimal readers for the pinned files

    private func file(_ name: String) throws -> String {
        try RepoPaths.text(RepoPaths.upstream.appendingPathComponent(name))
    }

    /// Rows of one layer of `iOS: primary:` as key tokens; `\s{…}`
    /// specials (shift, backspace, spacers) are dropped.
    private func russianLayer(_ name: String) throws -> [[String]] {
        let lines = try file("rus-3-rows.yaml").components(separatedBy: "\n")
        guard let primary = lines.firstIndex(of: "  primary:"),
              let start = lines[primary...].firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "\(name): |" }) else {
            XCTFail("layer \(name) not found"); return []
        }
        let indent = lines[start].prefix(while: { $0 == " " }).count
        var rows: [[String]] = []
        for line in lines[(start + 1)...] {
            let lineIndent = line.prefix(while: { $0 == " " }).count
            if line.trimmingCharacters(in: .whitespaces).isEmpty || lineIndent <= indent { break }
            rows.append(line.split(separator: " ").map(String.init).filter { !$0.hasPrefix("\\s{") })
        }
        return rows
    }

    // MARK: - Letter rows

    func testLetterRows() {
        XCTAssertEqual(spec.letterRows.map(characters), [
            ["й", "ц", "у", "к", "е", "н", "г", "ш", "ъ", "з", "х"],
            ["ф", "ы", "в", "а", "п", "р", "о", "л", "д", "ж", "\u{04C0}"],
            ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"],
        ])
        XCTAssertEqual(spec.letterRows.count, 3)
        // Shift and backspace frame the third row
        XCTAssertEqual(spec.letterRows[2].first, .shift)
        XCTAssertEqual(spec.letterRows[2].last, .backspace)
        // No letter twice, no row wider than the Russian keyboard's 11 keys
        XCTAssertEqual(Set(letterKeys).count, letterKeys.count)
        XCTAssertEqual(spec.letterRows.map { characters($0).count }, [11, 11, 9])
        // Every key is one Cyrillic character; the palochka is U+04C0
        for key in letterKeys {
            XCTAssertEqual(key.unicodeScalars.count, 1, key)
            XCTAssertTrue(Tsakhur.isTsakhurText(key), key)
        }
        XCTAssertEqual(letterKeys.filter { $0 == palochka }.count, 1)
        XCTAssertEqual(Array(palochka.unicodeScalars).map(\.value), [0x04C0])
        XCTAssertFalse(letterKeys.contains("\u{04CF}"))
        XCTAssertFalse(letterKeys.contains("I"))
        XCTAssertFalse(letterKeys.contains("l"))
    }

    /// The layout is the Russian iOS layout with exactly two keys changed:
    /// «ъ» where the Russian keyboard has «щ», «Ӏ» where it has «э».
    func testOnlyTwoKeysDifferFromTheRussianLayout() throws {
        let russian = try russianLayer("default")
        XCTAssertEqual(russian.map(\.count), [11, 11, 9])
        let tsakhur = spec.letterRows.map(characters)
        var differences: [String: String] = [:]
        for (r, row) in russian.enumerated() {
            for (i, key) in row.enumerated() where tsakhur[r][i] != key {
                differences[key] = tsakhur[r][i]
            }
        }
        XCTAssertEqual(differences, ["щ": "ъ", "э": palochka])
        // «Ӏ» ends the middle row, under «х»
        XCTAssertEqual(tsakhur[1].firstIndex(of: palochka), 10)
        XCTAssertEqual(tsakhur[0].firstIndex(of: "х"), 10)
        // «ъ» sits between «ш» and «з», two keys from «г» and from «х»
        XCTAssertEqual(tsakhur[0].firstIndex(of: "ъ"), 8)
        XCTAssertEqual(tsakhur[0].firstIndex(of: "г"), 6)
        // «ы», the fifth most frequent letter of Tsakhur, keeps its key
        // (the Dargwa, Tabasaran, Lak and Aghul keyboards give it to «Ӏ»)
        XCTAssertEqual(tsakhur[1].firstIndex(of: "ы"), 1)
        XCTAssertEqual(russian[1].firstIndex(of: "ы"), 1)
    }

    /// The shift layer the engine derives equals the Russian shift layer
    /// with the same two changes; the palochka has no other case.
    func testShiftLayer() throws {
        let upstream = try russianLayer("shift")
        let shifted = spec.letterRows.map { row in
            characters(row).map { KeyboardLayout.label(for: .character($0), shifted: true, capsLock: false) }
        }
        XCTAssertEqual(shifted, upstream.map { $0.map { $0 == "Щ" ? "Ъ" : $0 == "Э" ? palochka : $0 } })
        for capsLock in [false, true] {
            XCTAssertEqual(KeyboardLayout.label(for: .character(palochka), shifted: true, capsLock: capsLock), palochka)
        }
    }

    // MARK: - Number and symbol pages

    /// The pages of the Russian iOS keyboard, unchanged. The transcription
    /// writes the typographic “ and ’; the keyboard types the plain " and '
    /// like the sibling keyboards and offers the typographic ones on a
    /// long press.
    func testNumberAndSymbolPagesAreTheRussianOnes() throws {
        func plain(_ rows: [[String]]) -> [[String]] {
            rows.map { $0.map { $0 == "“" ? "\"" : $0 == "’" ? "'" : $0 } }
        }
        XCTAssertEqual(spec.numberRows.map(characters), plain(try russianLayer("symbols-1")))
        XCTAssertEqual(spec.symbolRows.map(characters), plain(try russianLayer("symbols-2")))
        XCTAssertEqual(spec.numberRows[2].first, .symbols)
        XCTAssertEqual(spec.symbolRows[2].first, .numbers)
        XCTAssertEqual(spec.numberRows[2].last, .backspace)
    }

    // MARK: - Long press

    func testLongPressMappings() {
        let p = palochka
        let mark = String(Tsakhur.mark)
        let letters: [String: [String]] = [
            "а": ["а" + p],
            "г": ["гь", "гъ", "г" + p],
            "д": ["дж"],
            "к": ["къ", "к" + p, "кь"],
            "л": ["л" + mark],
            "о": ["о" + p],
            "п": ["п" + p],
            "т": ["т" + p],
            "у": ["у" + p],
            "х": ["хъ", "хь"],
            "ц": ["ц" + p],
            "ч": ["ч" + p],
            "ы": ["ы" + p],
            "е": ["ё"],
            "ш": ["щ"],
            p: ["э"],
            "ь": [mark],
        ]
        for (key, alternates) in letters {
            XCTAssertEqual(spec.callouts[key], alternates, key)
        }
        // No other letter key has a long press: not «ъ», «ж» or «э»
        let letterCalloutKeys = spec.callouts.keys.filter { $0.first!.isLetter }
        XCTAssertEqual(Set(letterCalloutKeys), Set(letters.keys))
        // Every long-press base is a key of the layout, and no option
        // repeats its base key or another option
        let allKeys = Set((spec.letterRows + spec.numberRows + spec.symbolRows).flatMap(characters))
        for (key, alternates) in spec.callouts {
            XCTAssertTrue(allKeys.contains(key), "\(key) is not a key")
            XCTAssertFalse(alternates.contains(key), key)
            XCTAssertEqual(Set(alternates).count, alternates.count, key)
        }
        // No popup is wider than the base key and three options
        XCTAssertLessThanOrEqual(letters.values.map(\.count).max()!, 3)
    }

    /// Each digraph option is exactly two characters that start with its
    /// base key: a sequence, never a single code point, a Latin lookalike
    /// or the lookup palochka.
    func testDigraphOptionsInsertTheIntendedUnicodeSequences() {
        var offered: [String] = []
        for (key, alternates) in TsakhurLayout.digraphCallouts {
            for option in alternates {
                XCTAssertEqual(option.unicodeScalars.count, 2, option)
                XCTAssertEqual(option.count, 2, option)
                XCTAssertTrue(option.hasPrefix(key), option)
                XCTAssertTrue(Tsakhur.isTsakhurText(option), option)
                XCTAssertEqual(option, option.precomposedStringWithCanonicalMapping, option)
                offered.append(option)
            }
        }
        let soft = "л" + String(Tsakhur.mark)
        XCTAssertEqual(offered.sorted(), (Tsakhur.digraphs + [soft]).sorted())
        let expected: [[UInt32]] = [
            [0x0430, 0x04C0],                                       // аӀ
            [0x0433, 0x044A], [0x0433, 0x044C], [0x0433, 0x04C0],   // гъ гь гӀ
            [0x0434, 0x0436],                                       // дж
            [0x043A, 0x044A], [0x043A, 0x044C], [0x043A, 0x04C0],   // къ кь кӀ
            [0x043B, 0x02BC],                                       // лʼ
            [0x043E, 0x04C0], [0x043F, 0x04C0], [0x0442, 0x04C0],   // оӀ пӀ тӀ
            [0x0443, 0x04C0],                                       // уӀ
            [0x0445, 0x044A], [0x0445, 0x044C],                     // хъ хь
            [0x0446, 0x04C0], [0x0447, 0x04C0], [0x044B, 0x04C0],   // цӀ чӀ ыӀ
        ]
        XCTAssertEqual(expected.count, 18)
        XCTAssertEqual(Set(offered.map { Array($0.unicodeScalars).map(\.value) }), Set(expected))
        // The displaced Russian letters are single Cyrillic letters, the
        // mark is the modifier letter apostrophe and nothing else
        XCTAssertEqual(Array(spec.callouts[palochka]![0].unicodeScalars).map(\.value), [0x044D])   // э
        XCTAssertEqual(Array(spec.callouts["ш"]![0].unicodeScalars).map(\.value), [0x0449])        // щ
        XCTAssertEqual(Array(spec.callouts["е"]![0].unicodeScalars).map(\.value), [0x0451])        // ё
        XCTAssertEqual(Array(spec.callouts["ь"]![0].unicodeScalars).map(\.value), [0x02BC])        // ʼ
        // The ASCII apostrophe of the number page stays what it is
        XCTAssertTrue(spec.numberRows.flatMap(characters).contains("'"))
        XCTAssertFalse(spec.callouts["'"]!.contains(String(Tsakhur.mark)))
    }

    /// The symbol alternates are those of the Russian iOS keyboard.
    func testSymbolLongPressesAreTheRussianOnes() throws {
        var upstream: [String: [String]] = [:]
        for line in try file("rus-longpress.yaml").components(separatedBy: "\n") {
            guard let colon = line.range(of: ": ") else { continue }
            func unquote(_ s: Substring) -> String {
                let t = s.trimmingCharacters(in: .whitespaces)
                if t.count >= 2, let f = t.first, f == t.last, f == "'" || f == "\"" {
                    return String(t.dropFirst().dropLast())
                }
                return t
            }
            upstream[unquote(line[..<colon.lowerBound])] =
                unquote(line[colon.upperBound...]).split(separator: " ").map(String.init)
        }
        XCTAssertEqual(upstream["е"], spec.callouts["е"])
        for key in ["0", "₽", "#", ".", "%", "=", "-", "/", "&", "?", "!"] {
            XCTAssertEqual(spec.callouts[key], upstream[key], key)
        }
        // The quote alternates sit on this layout's ' and " keys; the
        // popup never repeats its base key
        XCTAssertEqual(spec.callouts["'"], upstream["’"]?.filter { $0 != "'" })
        XCTAssertEqual(spec.callouts["\""], upstream["“"]?.filter { $0 != "\"" })
    }

    // MARK: - Alphabet

    /// Every one of the 50 entries of the Tsakhur alphabet of 1990 (as
    /// «Языки народов Российской Федерации и соседних государств» and the
    /// Russian and English Wikipedia print it) can be typed.
    func testWholeAlphabetIsTypeable() {
        let p = palochka
        let alphabet = ["а", "а" + p, "б", "в", "г", "г" + p, "гъ", "гь", "д", "дж",
                        "е", "ё", "ж", "з", "и", "й", "к", "к" + p, "къ", "кь",
                        "л", "м", "н", "о", "о" + p, "п", "п" + p, "р", "с", "т",
                        "т" + p, "у", "у" + p, "ф", "х", "хъ", "хь", "ц", "ц" + p, "ч",
                        "ч" + p, "ш", "щ", "ъ", "ы", "ы" + p, "э", "ь", "ю", "я"]
        XCTAssertEqual(alphabet.count, 50)
        XCTAssertEqual(Set(alphabet).count, 50)
        let keys = Set(letterKeys)
        let longPress = Set(spec.callouts.filter { keys.contains($0.key) }.flatMap(\.value))
        for letter in alphabet {
            let fromKeys = letter.allSatisfy { keys.contains(String($0)) }
            XCTAssertTrue(fromKeys || longPress.contains(letter), "\(letter) cannot be typed")
        }
        // Every digraph both ways: key by key, and as one long press
        XCTAssertEqual(Set(Tsakhur.digraphs), Set(alphabet.filter { $0.count == 2 }))
        for digraph in Tsakhur.digraphs {
            XCTAssertTrue(digraph.allSatisfy { keys.contains(String($0)) }, digraph)
            XCTAssertTrue(longPress.contains(digraph), digraph)
        }
        // Doubled letters (long vowels, doubled consonants) need no long
        // press: the letter is a key
        for sequence in Tsakhur.doubled {
            XCTAssertTrue(sequence.allSatisfy { keys.contains(String($0)) }, sequence)
            XCTAssertFalse(longPress.contains(sequence), sequence)
        }
        // The only Russian letters without a key of their own
        let russian = Set("абвгдеёжзийклмнопрстуфхцчшщъыьэюя".map(String.init))
        XCTAssertEqual(russian.subtracting(keys), ["ё", "щ", "э"])
        XCTAssertTrue(longPress.isSuperset(of: ["ё", "щ", "э"]))
        // The palatalization mark, which is not a letter of the alphabet,
        // is one long press away, alone and after «л»
        XCTAssertTrue(longPress.contains(String(Tsakhur.mark)))
        XCTAssertTrue(longPress.contains("л" + String(Tsakhur.mark)))
        // Nothing is offered twice
        let options = spec.callouts.filter { keys.contains($0.key) }.flatMap(\.value)
        XCTAssertEqual(Set(options).count, options.count)
    }

    // MARK: - The evidence

    /// The layout rests on letter counts of Tsakhur newspaper text
    /// (docs/LAYOUT.md; docs/layout/nur_sample.json, written by
    /// scripts/measure_newspaper_sample.py). A new sample that no longer
    /// supports the claims fails here.
    func testNewspaperLetterCountsSupportTheLayout() throws {
        let data = try Data(contentsOf: RepoPaths.newspaperSample)
        let sample = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let letters = try XCTUnwrap(sample["letters"] as? [String: Int]).filter { $0.key != "-" }
        let digraphs = try XCTUnwrap(sample["digraphs"] as? [String: Int])
        let words = try XCTUnwrap(sample["words"] as? Int)
        XCTAssertGreaterThan(words, 20_000)
        let total = Double(letters.values.reduce(0, +))
        func share(_ ch: Character) -> Double { 100 * Double(letters[String(ch)] ?? 0) / total }
        func pair(_ d: String) -> Int { digraphs[d.replacingOccurrences(of: "\u{04C0}", with: "\u{04CF}")] ?? 0 }
        let p = palochka

        // «ъ» and the palochka are everyday letters; «щ» and «э», whose
        // keys they take, are the rarest of the Russian keyboard with «ю»
        XCTAssertEqual(share("ъ"), 3.33, accuracy: 0.05)
        XCTAssertEqual(share(Tsakhur.lookup), 2.41, accuracy: 0.05)
        XCTAssertEqual(share("щ"), 0.03, accuracy: 0.02)
        XCTAssertEqual(share("э"), 0.25, accuracy: 0.03)
        let rarest = "абвгдежзийклмнопрстуфхцчшщъыьэюя".sorted { share($0) < share($1) }.prefix(3)
        XCTAssertEqual(Set(rarest), ["щ", "ю", "э"])
        // «ы» is no key to give away: the fifth most frequent letter
        XCTAssertEqual(share("ы"), 4.61, accuracy: 0.05)
        XCTAssertEqual(letters.sorted { $0.value > $1.value }.prefix(5).map(\.key), ["а", "и", "н", "е", "ы"])
        // The palatalization mark is in one word of 27, and after «л» in
        // more than nine cases of ten
        let marked = try XCTUnwrap(sample["words_with_mark"] as? Int)
        XCTAssertEqual(100 * Double(marked) / Double(words), 3.7, accuracy: 0.2)
        let before = try XCTUnwrap(sample["letter_before_mark"] as? [String: Int])
        XCTAssertGreaterThan(Double(before["л"]!) / Double(before.values.reduce(0, +)), 0.9)
        // The newspaper types the palochka as a Latin I and the mark as an
        // apostrophe; the sample holds neither U+04C0 nor U+02BC
        let typed = try XCTUnwrap(sample["how_the_palochka_is_typed"] as? [String: Int])
        XCTAssertGreaterThan(typed["U+0049"]!, 3000)
        // Long-press order on the keys with several digraphs
        XCTAssertGreaterThan(pair("гь"), pair("гъ"))
        XCTAssertGreaterThan(pair("гъ"), pair("г" + p))
        XCTAssertGreaterThan(pair("къ"), pair("к" + p))
        XCTAssertGreaterThan(pair("к" + p), pair("кь"))
        XCTAssertGreaterThan(pair("хъ"), pair("хь"))
        // Half of all palochkas make the pharyngealized vowel «аӀ»
        let afterVowel = pair("а" + p) + pair("о" + p) + pair("у" + p) + pair("ы" + p)
        XCTAssertGreaterThan(Double(pair("а" + p)) / Double(letters[String(Tsakhur.lookup)]!), 0.5)
        XCTAssertGreaterThan(Double(afterVowel) / Double(letters[String(Tsakhur.lookup)]!), 0.6)
        // What is not in the alphabet is not in the newspaper either
        for absent in ["аь", "оь", "уь"] { XCTAssertEqual(pair(absent), 0, absent) }
        XCTAssertLessThan(pair("х" + p), 5)
    }

    /// The shipped dictionary, a word list in which every word counts
    /// once, shows the same letters as everyday and the same as rare.
    func testDictionaryLetterCountsAgree() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.wordsArtifact.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT word FROM words", -1, &stmt, nil), SQLITE_OK)
        var characters: [Character: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            for ch in String(cString: sqlite3_column_text(stmt, 0)) where ch != "-" {
                characters[ch, default: 0] += 1
            }
        }
        sqlite3_finalize(stmt)
        let total = Double(characters.values.reduce(0, +))
        func share(_ ch: Character) -> Double { 100 * Double(characters[ch] ?? 0) / total }
        XCTAssertGreaterThan(share("ъ"), 3)
        XCTAssertGreaterThan(share(Tsakhur.lookup), 3)
        XCTAssertGreaterThan(share("ы"), 3)
        XCTAssertLessThan(share("щ"), 0.1)
        XCTAssertLessThan(share("э"), 0.5)
        XCTAssertGreaterThan(share(Tsakhur.mark), 0.5)
    }
}
