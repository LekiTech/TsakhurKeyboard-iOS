//
//  TsakhurTestCase.swift
//  TsakhurCoreTests
//
//  Base class for every test that touches the engine: installs the
//  Tsakhur definition before the engine's statics capture it, exactly as
//  the extension's principal class does. Also the repository paths the
//  tests read (the shipped artifacts, the pinned upstream files, the
//  project).
//

import XCTest
import UIKit
@testable import TsakhurCore
@testable import GeneralKeyboard

class TsakhurTestCase: XCTestCase {
    override class func setUp() {
        super.setUp()
        KeyboardDefinition.install(TsakhurDefinition.definition)
    }
}

enum RepoPaths {
    /// The repository root, from this file's location
    /// (Tests/TsakhurCoreTests/Support/TsakhurTestCase.swift).
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Support
        .deletingLastPathComponent()   // TsakhurCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repository root

    static let extensionFolder = root.appendingPathComponent("TsakhurKeyboard/TsakhurKeyboardExtension")
    static let wordsArtifact = extensionFolder.appendingPathComponent("tsakhur_words.sqlite")
    static let bigramsArtifact = extensionFolder.appendingPathComponent("tsakhur_bigrams.sqlite")
    static let upstream = root.appendingPathComponent("Tests/TsakhurCoreTests/Fixtures/agisight")
    static let project = root.appendingPathComponent("TsakhurKeyboard/TsakhurKeyboard.xcodeproj/project.pbxproj")
    static let newspaperSample = root.appendingPathComponent("docs/layout/nur_sample.json")

    static func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}

/// The palochka in its two roles, the palatalization mark and the
/// two-character letters of the alphabet.
enum Tsakhur {
    /// Ӏ U+04C0: what keys, suggestions and every string show and insert.
    static let visible: Character = "\u{04C0}"
    /// ӏ U+04CF: the lookup form inside the artifacts and the learned store.
    static let lookup: Character = "\u{04CF}"
    /// ʼ U+02BC: the palatalization mark, typed and stored alike.
    static let mark: Character = "\u{02BC}"

    /// The seventeen two-character letters of the alphabet of 1990, written
    /// as the keyboard types them. All are offered on a long press.
    static let digraphs = ["а\u{04C0}", "гъ", "гь", "г\u{04C0}", "дж", "къ", "кь", "к\u{04C0}", "о\u{04C0}",
                           "п\u{04C0}", "т\u{04C0}", "у\u{04C0}", "хъ", "хь", "ц\u{04C0}", "ч\u{04C0}", "ы\u{04C0}"]
    /// Doubled letters of the spelling, typed by tapping the key twice: the
    /// long vowels and the commonest doubled consonants.
    static let doubled = ["аа", "ее", "оо", "лл", "кк", "хх"]

    /// Only Cyrillic letters of the Russian alphabet, the visible palochka
    /// and the palatalization mark.
    static func isTsakhurText(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy {
            (0x0410...0x044F).contains($0.value) || $0.value == 0x0401 || $0.value == 0x0451
                || $0.value == 0x04C0 || $0.value == 0x02BC
        }
    }
}

/// A minimal host text field: the context before the cursor is all the
/// suggestion and capitalization logic reads (same as General Keyboard's
/// test double).
final class MockTextDocumentProxy: NSObject, UITextDocumentProxy {
    var before: String
    init(before: String = "") { self.before = before }

    var documentContextBeforeInput: String? { before }
    var documentContextAfterInput: String? { nil }
    var selectedText: String? { nil }
    var documentInputMode: UITextInputMode? { nil }
    var documentIdentifier: UUID { UUID() }
    var hasText: Bool { !before.isEmpty }
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var returnKeyType: UIReturnKeyType = .default

    func adjustTextPosition(byCharacterOffset offset: Int) {}
    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
    func insertText(_ text: String) { before += text }
    func deleteBackward() { if !before.isEmpty { before.removeLast() } }
}
