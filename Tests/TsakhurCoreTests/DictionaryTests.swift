//
//  DictionaryTests.swift
//  TsakhurCoreTests
//
//  The SHIPPED artifacts (TsakhurKeyboardExtension/tsakhur_words.sqlite
//  and tsakhur_bigrams.sqlite, built by scripts/build_dictionary.py)
//  through the engine's readers: metadata, counts, the canonical form of
//  every lookup key, prefix suggestions, next words from the pairs of the
//  multiword dictionary forms, the palatalization mark inside a word, and
//  the repair of what the v0 reading cut. The figures are those of cleanup
//  version 1 (docs/DICTIONARY.md).
//

import XCTest
import SQLite3
@testable import TsakhurCore
@testable import GeneralKeyboard

final class DictionaryTests: TsakhurTestCase {

    private var words: WordSuggestions!
    private var bigrams: StaticBigrams!

    override func setUpWithError() throws {
        try super.setUpWithError()
        words = try XCTUnwrap(WordSuggestions(databaseURL: RepoPaths.wordsArtifact))
        bigrams = try XCTUnwrap(StaticBigrams(databaseURL: RepoPaths.bigramsArtifact))
    }

    private func meta(_ url: URL) throws -> [String: String] {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT key, value FROM meta", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var values: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            values[String(cString: sqlite3_column_text(stmt, 0))] = String(cString: sqlite3_column_text(stmt, 1))
        }
        return values
    }

    func testArtifactMetadata() throws {
        let w = try XCTUnwrap(words.metadata)
        XCTAssertEqual(w.artifact, "tsakhur_words")
        XCTAssertEqual(w.schemaVersion, 1)
        XCTAssertEqual(w.contentVersion, 1)
        XCTAssertEqual(w.normalizationVersion, Normalization.version)
        XCTAssertEqual(w.minReaderSchema, 1)
        XCTAssertEqual(w.rowCount, 1355)
        let b = try XCTUnwrap(bigrams.metadata)
        XCTAssertEqual(b.artifact, "tsakhur_bigrams")
        XCTAssertEqual(b.rowCount, 134)
        XCTAssertEqual(b.normalizationVersion, Normalization.version)
        XCTAssertFalse(bigrams.isEmpty)
        // Both artifacts name the profile they are canonical under
        for url in [RepoPaths.wordsArtifact, RepoPaths.bigramsArtifact] {
            let values = try meta(url)
            XCTAssertEqual(values["normalization_profile"], KeyboardDefinition.current.normalization.id)
            XCTAssertEqual(values["normalization_profile"], "tsakhur-cyrillic")
            XCTAssertEqual(values["language"], "tkr")
            XCTAssertEqual(values["cleanup_version"], "1")
        }
    }

    /// Every stored key is already canonical (lowercase, NFC, palochka
    /// U+04CF, mark U+02BC), valid under the token contract and written
    /// with Tsakhur letters only, and every bigram word is a row of the
    /// words artifact, so a lookup never misses by representation.
    func testEveryRowIsCanonicalAndValid() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.wordsArtifact.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT word, base_score FROM words", -1, &stmt, nil), SQLITE_OK)
        var all = Set<String>()
        var scores = Set<Int>()
        var withPalochka = 0, withMark = 0, withShortI = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = String(cString: sqlite3_column_text(stmt, 0))
            scores.insert(Int(sqlite3_column_int64(stmt, 1)))
            XCTAssertTrue(Normalization.isCanonical(word), word)
            XCTAssertTrue(Normalization.isValidToken(word), word)
            XCTAssertFalse(word.contains(Tsakhur.visible), "\(word) stores the visible palochka U+04C0")
            XCTAssertFalse(word.contains("\u{04CF}\u{04CF}"), "\(word) has a doubled palochka")
            XCTAssertFalse(word.unicodeScalars.contains { $0.properties.canonicalCombiningClass != .notReordered },
                           "\(word) has a combining mark")
            XCTAssertFalse(word.hasPrefix(String(Tsakhur.mark)), word)
            let letters = word.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "\u{04CF}", with: "")
            XCTAssertTrue(Tsakhur.isTsakhurText(letters), word)
            withPalochka += word.contains(Tsakhur.lookup) ? 1 : 0
            withMark += word.contains(Tsakhur.mark) ? 1 : 0
            withShortI += word.contains("й") ? 1 : 0
            all.insert(word)
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(all.count, 1355)
        XCTAssertEqual(withPalochka, 314)
        XCTAssertEqual(withMark, 67)
        XCTAssertEqual(withShortI, 210)
        // A word list without frequencies: every word has the score of a
        // word-list entry, none is made up
        XCTAssertEqual(scores, [1])

        var bdb: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.bigramsArtifact.path, &bdb, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(bdb) }
        XCTAssertEqual(sqlite3_prepare_v2(bdb, "SELECT prev, word, weight FROM bigrams", -1, &stmt, nil), SQLITE_OK)
        var pairs = 0, weight = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let prev = String(cString: sqlite3_column_text(stmt, 0))
            let word = String(cString: sqlite3_column_text(stmt, 1))
            XCTAssertTrue(all.contains(prev), prev)
            XCTAssertTrue(all.contains(word), word)
            XCTAssertGreaterThanOrEqual(sqlite3_column_int64(stmt, 2), 1)
            weight += Int(sqlite3_column_int64(stmt, 2))
            pairs += 1
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(pairs, 134)
        XCTAssertEqual(weight, 137)
    }

    /// With equal scores the shortest candidates come first, for prefixes
    /// that end inside or right after a two-character letter and for
    /// prefixes with the palatalization mark.
    func testPrefixSuggestions() {
        XCTAssertEqual(words.suggestions(for: "миз"), ["миз", "мизер"])
        XCTAssertEqual(words.suggestions(for: "йиг"), ["йигъ", "йигӏыд"])
        XCTAssertEqual(words.suggestions(for: "эв"), ["эва", "эвхас"])
        XCTAssertEqual(words.suggestions(for: "айг"), ["айгъыр"])
        XCTAssertEqual(words.suggestions(for: "ул"), ["улʼ"])
        XCTAssertEqual(words.suggestions(for: "хылʼ"), ["хылʼ"])
        XCTAssertEqual(words.suggestions(for: "кӏылʼ"), ["кӏылʼна"])
        XCTAssertEqual(words.suggestions(for: "кьадал"), ["кьадалий"])
        for prefix in ["кӏ", "цӏ", "чӏ", "тӏ", "аӏ", "оӏ", "ыӏ", "гъ", "гь", "хъ", "хь", "къ", "кь", "дж", "йи", "э"] {
            let found = words.suggestions(for: prefix)
            XCTAssertEqual(found.count, 3, prefix)
            XCTAssertEqual(found.map(\.count), found.map(\.count).sorted(), prefix)
            for word in found {
                XCTAssertTrue(word.hasPrefix(prefix), "\(word) for \(prefix)")
                XCTAssertTrue(words.contains(word), word)
            }
        }
        // «цӏ» is not answered with words in plain «ц»
        XCTAssertTrue(words.suggestions(for: "цӏ").allSatisfy { $0.hasPrefix("цӏ") })
        // No word begins with «щ» or «ё»
        XCTAssertEqual(words.suggestions(for: "щ"), [])
        XCTAssertEqual(words.suggestions(for: "ё"), [])
        XCTAssertEqual(words.suggestions(for: "ъъъ"), [])
    }

    /// A prefix typed with the keyboard's Ӏ (U+04C0) and ʼ (U+02BC), in
    /// capitals, with the Latin I and the apostrophe ’ that the newspaper
    /// prints, or in decomposed Unicode reaches the same rows.
    func testPrefixLookupNormalizesThePalochkaAndTheMark() {
        let canonical = words.suggestions(for: "кӏылʼ")
        XCTAssertEqual(canonical, ["кӏылʼна"])
        XCTAssertEqual(words.suggestions(for: "к\u{04C0}ыл\u{02BC}"), canonical)      // U+04C0, U+02BC
        XCTAssertEqual(words.suggestions(for: "К\u{04C0}ЫЛ\u{02BC}"), canonical)
        XCTAssertEqual(words.suggestions(for: "кIыл\u{2019}"), canonical)             // Latin I, ’
        XCTAssertEqual(words.suggestions(for: "kIыл`"), canonical)                    // Latin k and I, `
        XCTAssertEqual(words.suggestions(for: "а\u{04C0}к\u{04C0}ол"), ["аӏкӏолʼ"])
        XCTAssertTrue(words.contains("К\u{04C0}ыл\u{2019}на"))
        XCTAssertTrue(words.contains("А\u{04C0}К\u{04C0}ОЛ\u{02BC}"))
        XCTAssertTrue(words.contains("о\u{04C0}лка"))
        XCTAssertTrue(words.contains("кьадалии\u{0306}"))                             // й as и + breve
        XCTAssertEqual(words.suggestions(for: "аи\u{0306}г"), ["айгъыр"])
    }

    /// The mark belongs to its word: «хылʼ» is a row and its bare stem is
    /// not, and a word is found whichever apostrophe it was typed with.
    func testThePalatalizationMarkIsPartOfTheWord() {
        for word in ["хылʼ", "улʼ", "едʼ", "голʼ", "кулʼ", "аӏкӏолʼ", "кӏылʼна", "колʼга", "кӏыпʼкӏам", "мазʼ"] {
            XCTAssertTrue(words.contains(word), word)
        }
        for stem in ["хыл", "ул", "ед", "гол", "кул", "кӏылна", "колга"] {
            XCTAssertFalse(words.contains(stem), stem)
        }
        XCTAssertEqual(Normalization.letterCount("улʼ"), 2)
        XCTAssertTrue(Normalization.isValidToken("улʼ"))
        // «миз» is in the list without the mark; the newspaper prints both
        XCTAssertTrue(words.contains("миз"))
        XCTAssertFalse(words.contains("мизʼ"))
    }

    /// The repair of cleanup version 1 (docs/DICTIONARY.md): the words v0
    /// cut are whole, the pieces are gone.
    func testWordsCutByV0AreWholeAgain() {
        // R1 / P1: «й» stored as и + combining breve
        for (word, pieces) in [("кьадалий", ["кьадалии"]), ("айгъыр", ["аи", "гъыр"]), ("йигъ", ["игъ"]),
                               ("дюнйе", ["дюни"]), ("балугъчий", ["балугъчии"]), ("йыӏхъ", ["ыӏхъ"])] {
            XCTAssertTrue(words.contains(word), word)
            for piece in pieces { XCTAssertFalse(words.contains(piece), piece) }
        }
        // R1 / P1: the palatalization mark
        for (word, pieces) in [("голʼ", ["гол"]), ("колʼга", ["кол", "га"]), ("къаравулʼ", ["къаравул"]),
                               ("игъвалʼдешвалла", ["игъвал", "дешвалла"])] {
            XCTAssertTrue(words.contains(word), word)
            for piece in pieces { XCTAssertFalse(words.contains(piece), piece) }
        }
        // R1: a Latin «c» typed for «с»
        XCTAssertTrue(words.contains("гьачӏиеъас"));     XCTAssertFalse(words.contains("гьачӏиеъа"))
        // X1: the four forms with a macron are set aside, their pieces removed
        for piece in ["си", "мишаас", "мишхьес", "ури"] {
            XCTAssertFalse(words.contains(piece), piece)
        }
        // A word that is also the end of a longer one stays: both are in the list
        XCTAssertTrue(words.contains("хьян"));           XCTAssertTrue(words.contains("гьаъас"))
    }

    /// What the rules deliberately leave alone.
    func testNothingWasRespelledOrMerged() {
        // «й» + vowel where the newspaper writes я, ю: kept and flagged
        XCTAssertTrue(words.contains("йубка"));          XCTAssertFalse(words.contains("юбка"))
        XCTAssertTrue(words.contains("шлйапа"));         XCTAssertFalse(words.contains("шляпа"))
        // Two spellings of one word in the list: both kept, neither merged
        XCTAssertTrue(words.contains("хʼян"));           XCTAssertTrue(words.contains("хьян"))
        // Letters the alphabet of 1990 does not have: kept and flagged
        XCTAssertTrue(words.contains("оьца"));           XCTAssertTrue(words.contains("кухӏ"))
        // Long vowels and doubled consonants are written twice
        XCTAssertTrue(words.contains("аазыр"));          XCTAssertTrue(words.contains("баттагъ"))
        // Hyphenated dictionary entries stay
        XCTAssertTrue(words.contains("цык-цык"));        XCTAssertTrue(words.contains("экӏда-экӏда"))
        // A name is a lowercase row like every other word
        XCTAssertTrue(words.contains("аллагь"))
        // The second word of the language's self-name
        XCTAssertTrue(words.contains("миз"))
    }

    /// The pairs are the neighbouring words of the multiword forms of the
    /// word list (rule B1); the weight is the number of forms with the pair.
    func testNextWordsComeFromTheMultiwordForms() {
        XCTAssertEqual(bigrams.nextWords(after: "кӏылʼна"), ["йичи", "чодж"])      // younger sister, younger brother
        XCTAssertEqual(bigrams.nextWords(after: "эва"), ["гьаъас", "къа"])
        XCTAssertEqual(bigrams.nextWords(after: "двухна"), ["дек", "едʼ", "йиш"])
        XCTAssertEqual(bigrams.nextWords(after: "кӏалыб"), ["гьачӏиеъас"])
        XCTAssertEqual(bigrams.nextWords(after: "къоппагъ"), ["кулʼ"])
        XCTAssertEqual(bigrams.nextWords(after: "К\u{04C0}ыл\u{2019}на"), ["йичи", "чодж"])
        XCTAssertEqual(bigrams.nextWords(after: "гьаъас"), [])
        XCTAssertEqual(bigrams.nextWords(after: "ъъъ"), [])
        // Static context reorders dictionary candidates among themselves
        let weights = bigrams.weights(after: "эва", candidates: ["къа", "гьаъас", "ъъъ"])
        XCTAssertEqual(weights, ["гьаъас": 2, "къа": 1])
    }

    func testRandomIdleWordsComeFromTheDictionary() {
        let idle = words.randomWords(3)
        XCTAssertEqual(idle.count, 3)
        for word in idle { XCTAssertTrue(words.contains(word), word) }
    }
}
