import Foundation
import Testing
@testable import LangPilot

@Test func swapsLayouts() {
    #expect(Converter.swap("ghbdtn") == "привет")
    #expect(Converter.swap("руддщ") == "hello")
}

@Test func suggestsOnlyKnownWords() {
    #expect(Converter.suggestion(for: "ghbdtn")?.0 == "привет")
    #expect(Converter.suggestion(for: "рщц")?.0 == "how")
    #expect(Converter.suggestion(for: "фку")?.0 == "are")
    #expect(Converter.suggestion(for: "нщг")?.0 == "you")
    #expect(Converter.suggestion(for: "ящг")?.0 == "you")
    #expect(Converter.suggestion(for: "lf")?.0 == "да")
    #expect(Converter.suggestion(for: "ctqxfc")?.0 == "сейчас")
    #expect(Converter.suggestion(for: "pf")?.0 == "за")
    #expect(Converter.swap(",hfn") == "брат")
    #expect(Converter.suggestion(for: "github") == nil)
}

@MainActor
@Test func exportsAndImportsLearning() throws {
    UserDefaults.standard.removeObject(forKey: "learning.v1")
    let store = LearningStore()
    store.recordAccepted(original: "ghbdtn", replacement: "привет")
    store.recordAccepted(original: "ghbdtn", replacement: "привет")

    let data = try store.exportData()
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(LearningStore.ExportFile.self, from: data)
    #expect(decoded.version == 1)
    #expect(decoded.pairs.count == 1)
    #expect(decoded.pairs.first?.original == "ghbdtn")
    #expect(decoded.pairs.first?.replacement == "привет")
    #expect(decoded.pairs.first?.accepted == 2)

    UserDefaults.standard.removeObject(forKey: "learning.v1")
    let imported = LearningStore()
    let importedCount = try imported.importData(data)
    #expect(importedCount == 1)
    #expect(imported.shouldApply(original: "ghbdtn", replacement: "привет"))
    UserDefaults.standard.removeObject(forKey: "learning.v1")
}
