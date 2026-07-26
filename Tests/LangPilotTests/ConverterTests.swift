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
