import AppKit
import ApplicationServices
import Carbon
import ServiceManagement

enum Layout: String, CaseIterable {
    case russian, abc, german

    static var current: Layout {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return .abc }
        let id = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
        if id.localizedCaseInsensitiveContains("Russian") { return .russian }
        if id.localizedCaseInsensitiveContains("German") { return .german }
        return .abc
    }

    func activate() {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return }
        for source in list {
            guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
            let match: Bool
            switch self {
            case .russian: match = id.localizedCaseInsensitiveContains("Russian")
            case .german: match = id.localizedCaseInsensitiveContains("German")
            case .abc: match = id.hasSuffix(".ABC") || id.hasSuffix(".US")
            }
            if match { TISSelectInputSource(source); return }
        }
    }
}

struct Converter {
    private static let latin = Array("`qwertyuiop[]asdfghjkl;'zxcvbnm,./")
    private static let russian = Array("ёйцукенгшщзхъфывапролджэячсмитьбю.")
    private static let commonRussian = Set([
        "привет", "спасибо", "пожалуйста", "можно", "нужно", "будет", "тебя", "меня", "если", "когда",
        "тогда", "очень", "хорошо", "сегодня", "завтра", "работа", "работает", "сделать", "почему", "потому",
        "да", "нет", "сейчас", "за", "для", "как", "дела", "давай", "думаю", "знаю", "понимаю",
        "русский", "язык", "текст", "слово", "время", "просто"
    ])
    private static let commonLatin = Set([
        "hello", "thanks", "please", "today", "tomorrow", "work", "works", "text", "word", "language",
        "the", "this", "that", "with", "from", "have", "will", "can", "good", "very", "how", "are", "you",
        "what", "where", "who", "why", "when", "yes", "not", "and", "your", "my", "me", "we", "they",
        "und", "der", "die",
        "das", "ist", "ich", "nicht", "mit", "für", "danke", "bitte", "heute", "morgen", "hallo"
    ])

    static func swap(_ text: String) -> String {
        let lower = text.lowercased()
        let toRussian = lower.unicodeScalars.allSatisfy { $0.isASCII }
        let from = toRussian ? latin : russian
        let to = toRussian ? russian : latin
        let table = Dictionary(uniqueKeysWithValues: zip(from, to))
        return String(text.map { character in
            let wasUpper = character.isUppercase
            let base = Character(String(character).lowercased())
            guard let mapped = table[base] else { return character }
            return Character(wasUpper ? String(mapped).uppercased() : String(mapped))
        })
    }

    static func suggestion(for word: String) -> (String, Layout)? {
        let converted = swap(word)
        guard word.count >= 2, converted.allSatisfy({ $0.isLetter }) else { return nil }
        let originalLower = word.lowercased()
        let convertedLower = converted.lowercased()
        if commonRussian.contains(convertedLower), !commonLatin.contains(originalLower) { return (converted, .russian) }
        if commonLatin.contains(convertedLower), !commonRussian.contains(originalLower) {
            let target: Layout = Set(convertedLower).isDisjoint(with: Set("äöüß")) ? .abc : .german
            return (converted, target)
        }
        // On a German ISO keyboard users often press the physical Z key for the
        // English letter Y. Russian then receives "я" instead of "н".
        if originalLower == "ящг" { return (preservingCase(from: word, as: "you"), .abc) }
        return nil
    }

    private static func preservingCase(from source: String, as replacement: String) -> String {
        source.first?.isUppercase == true ? replacement.prefix(1).uppercased() + replacement.dropFirst() : replacement
    }
}

enum SpellingMode: String, CaseIterable {
    case suggest, automatic, off

    var title: String {
        switch self {
        case .suggest: return "Орфография: предлагать"
        case .automatic: return "Орфография: автоисправление"
        case .off: return "Орфография: выключена"
        }
    }

    var next: SpellingMode {
        switch self {
        case .suggest: return .automatic
        case .automatic: return .off
        case .off: return .suggest
        }
    }
}

/// Persistent, local feedback model. It stores only word pairs and counters,
/// never surrounding text or application contents.
@MainActor
final class LearningStore {
    struct ExportFile: Codable {
        struct Pair: Codable {
            var original: String
            var replacement: String
            var accepted: Int
            var rejected: Int
        }

        var version: Int
        var exportedAt: Date
        var pairs: [Pair]
    }

    private struct Record: Codable {
        var accepted = 0
        var rejected = 0
    }
    private var records: [String: Record] = [:]
    private let defaultsKey = "learning.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode([String: Record].self, from: data) else { return }
        records = saved
    }

    func recordAccepted(original: String, replacement: String) {
        let key = makeKey(original, replacement)
        var record = records[key, default: Record()]
        record.accepted += 1
        records[key] = record
        save()
    }

    func recordRejected(original: String, replacement: String) {
        let key = makeKey(original, replacement)
        var record = records[key, default: Record()]
        record.rejected += 2 // An explicit undo must outweigh an earlier acceptance.
        records[key] = record
        save()
    }

    func shouldApply(original: String, replacement: String) -> Bool {
        let record = records[makeKey(original, replacement), default: Record()]
        return record.accepted >= 2 && record.accepted > record.rejected
    }

    func isBlocked(original: String, replacement: String) -> Bool {
        let record = records[makeKey(original, replacement), default: Record()]
        return record.rejected >= record.accepted + 1
    }

    func entries() -> [String] {
        records.keys.sorted().map { key in
            let parts = key.components(separatedBy: "\u{1f}")
            return parts.count == 2 ? "\(parts[0]) → \(parts[1])" : key
        }
    }

    func exportData() throws -> Data {
        let pairs = records.keys.sorted().compactMap { key -> ExportFile.Pair? in
            let parts = key.components(separatedBy: "\u{1f}")
            guard parts.count == 2, let record = records[key] else { return nil }
            return ExportFile.Pair(original: parts[0], replacement: parts[1],
                                   accepted: record.accepted, rejected: record.rejected)
        }
        let file = ExportFile(version: 1, exportedAt: Date(), pairs: pairs)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(file)
    }

    @discardableResult
    func importData(_ data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(ExportFile.self, from: data)
        guard file.version == 1 else { throw ImportError.unsupportedVersion(file.version) }

        var imported = 0
        for pair in file.pairs {
            let original = pair.original.trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = pair.replacement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !original.isEmpty, !replacement.isEmpty else { continue }
            let key = makeKey(original, replacement)
            var record = records[key, default: Record()]
            record.accepted = max(record.accepted, pair.accepted)
            record.rejected = max(record.rejected, pair.rejected)
            records[key] = record
            imported += 1
        }
        save()
        return imported
    }

    func reset() {
        records.removeAll()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    enum ImportError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "Unsupported LangPilot learning export version: \(version)"
            }
        }
    }

    private func makeKey(_ original: String, _ replacement: String) -> String {
        original.lowercased() + "\u{1f}" + replacement.lowercased()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

@MainActor
final class InputMonitor {
    private static let injectedEventMarker: Int64 = 0x4C_50_4C_54
    private let learning = LearningStore()
    var enabled = true
    var soundEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundEnabled") }
    }
    var spellingMode: SpellingMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "spellingMode"),
                  let mode = SpellingMode(rawValue: raw) else { return .suggest }
            return mode
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "spellingMode") }
    }
    var suggestionDuration: TimeInterval {
        get {
            let value = UserDefaults.standard.double(forKey: "suggestionDuration")
            return value > 0 ? value : 8
        }
        set { UserDefaults.standard.set(newValue, forKey: "suggestionDuration") }
    }
    var excludedBundleIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: "excludedBundleIDs") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "excludedBundleIDs") }
    }
    var onSpellingSuggestion: ((String?) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var word = ""
    private var lastCompletedWord = ""
    private var lastReplacement: (original: String, replacement: String, trailing: String, automatic: Bool)?
    private struct PendingSpelling {
        let original: String
        let replacement: String
        let trailing: String
        var typedAfter = ""
    }
    private var spellingSuggestion: PendingSpelling?
    private var injecting = false

    func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard type == .keyDown, let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue()
            let consumed = MainActor.assumeIsolated { monitor.handle(event) }
            return consumed ? nil : Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: callback,
                                userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return false }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(_ event: CGEvent) -> Bool {
        guard enabled, !injecting,
              event.getIntegerValueField(.eventSourceUserData) != Self.injectedEventMarker else { return false }
        guard isInputAllowed() else {
            word = ""
            clearSpellingSuggestion()
            return false
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        if flags.contains([.maskCommand, .maskAlternate]) {
            if key == 37 { correctLastManually(); return true } // Option-Command-L
            if key == 6 { undo(); return true }                 // Option-Command-Z
            if key == 1 { applySpellingSuggestion(); return true } // Option-Command-S
        }
        if spellingSuggestion != nil {
            if key == 48 { applySpellingSuggestion(); return true } // Tab
            if key == 53 { clearSpellingSuggestion(); return true } // Escape
            if [115, 116, 117, 119, 121, 123, 124, 125, 126].contains(key) {
                clearSpellingSuggestion()
            }
        }
        if key == 51 {
            if spellingSuggestion?.typedAfter.isEmpty == false {
                spellingSuggestion?.typedAfter.removeLast()
            } else if spellingSuggestion != nil {
                clearSpellingSuggestion()
            }
            if !word.isEmpty { word.removeLast() }
            return false
        }
        guard let nsEvent = NSEvent(cgEvent: event), let chars = nsEvent.characters, !chars.isEmpty else { return false }
        spellingSuggestion?.typedAfter += chars
        // Several Russian letters live on punctuation keys in ABC/German
        // (б, ю, ж, э, х, ъ, ё). Keep those keystrokes inside the candidate
        // and decide only when a space/newline completes the word.
        let layoutLetters = "`[];',./"
        if chars.allSatisfy({ $0.isLetter }) ||
            (Layout.current != .russian && chars.allSatisfy({ layoutLetters.contains($0) })) {
            word += chars
            return false
        }
        if chars == " " || chars == "\n" || chars.rangeOfCharacter(from: .punctuationCharacters) != nil {
            completeWord(trailing: chars)
        } else if !chars.allSatisfy({ $0.isNumber }) { word = "" }
        return false
    }

    func correctLastManually() {
        let afterDelimiter = word.isEmpty
        let candidate = afterDelimiter ? lastCompletedWord : word
        guard !candidate.isEmpty else { return }
        word = candidate
        let replacement = Converter.swap(candidate)
        learning.recordAccepted(original: candidate, replacement: replacement)
        replaceLastWord(with: replacement, trailing: afterDelimiter ? " " : "", automatic: false)
        let target: Layout = Layout.current == .russian ? .abc : .russian
        switchLayout(to: target)
    }

    func undo() {
        guard let lastReplacement else { return }
        learning.recordRejected(original: lastReplacement.original, replacement: lastReplacement.replacement)
        injecting = true
        postBackspaces(lastReplacement.replacement.count + lastReplacement.trailing.count)
        postText(lastReplacement.original + lastReplacement.trailing)
        injecting = false
        self.lastReplacement = nil
    }

    func applySpellingSuggestion() {
        guard let suggestion = spellingSuggestion else { return }
        injecting = true
        let suffix = suggestion.trailing + suggestion.typedAfter
        postBackspaces(suggestion.original.count + suffix.count)
        postText(suggestion.replacement + suffix)
        injecting = false
        lastReplacement = (suggestion.original, suggestion.replacement, suffix, false)
        clearSpellingSuggestion()
        if soundEnabled { NSSound(named: NSSound.Name("Pop"))?.play() }
    }

    func dismissSpellingSuggestion() {
        clearSpellingSuggestion()
    }

    func learnedEntries() -> [String] { learning.entries() }
    func exportLearningData() throws -> Data { try learning.exportData() }
    @discardableResult
    func importLearningData(_ data: Data) throws -> Int { try learning.importData(data) }
    func resetLearning() { learning.reset() }

    private func completeWord(trailing: String) {
        let completed = word
        defer { lastCompletedWord = completed; word = "" }
        guard !completed.isEmpty else { return }
        let converted = Converter.swap(word)
        let builtIn = Converter.suggestion(for: word) ?? systemDictionarySuggestion(for: word, converted: converted)
        let replacement: String
        let layout: Layout
        if let builtIn, !learning.isBlocked(original: word, replacement: builtIn.0) {
            (replacement, layout) = builtIn
        } else if learning.shouldApply(original: word, replacement: converted) {
            replacement = converted
            layout = word.unicodeScalars.allSatisfy(\.isASCII) ? .russian : .abc
        } else {
            checkSpelling(of: completed, trailing: trailing)
            return
        }
        replaceLastWord(with: replacement, trailing: trailing, automatic: true)
        switchLayout(to: layout)
        clearSpellingSuggestion()
    }

    private func checkSpelling(of candidate: String, trailing: String) {
        guard spellingMode != .off,
              candidate.count >= 3,
              candidate.allSatisfy(\.isLetter) else { return }
        let language: String
        switch Layout.current {
        case .russian: language = "ru_RU"
        case .german: language = "de_DE"
        case .abc: language = "en_US"
        }
        let checker = NSSpellChecker.shared
        let range = NSRange(location: 0, length: (candidate as NSString).length)
        let misspelled = checker.checkSpelling(of: candidate, startingAt: 0, language: language,
                                               wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
        guard misspelled.location != NSNotFound,
              let guesses = checker.guesses(forWordRange: range, in: candidate, language: language,
                                            inSpellDocumentWithTag: 0),
              let best = rankedSpellingGuesses(guesses, for: candidate).first,
              best.caseInsensitiveCompare(candidate) != .orderedSame,
              !learning.isBlocked(original: candidate, replacement: best) else { return }

        if spellingMode == .automatic && isConfidentSpellingFix(from: candidate, to: best) {
            word = candidate
            replaceLastWord(with: best, trailing: trailing, automatic: true)
            if soundEnabled { NSSound(named: NSSound.Name("Pop"))?.play() }
        } else {
            spellingSuggestion = PendingSpelling(original: candidate, replacement: best, trailing: trailing)
            onSpellingSuggestion?(best)
        }
    }

    private func rankedSpellingGuesses(_ guesses: [String], for original: String) -> [String] {
        guesses.enumerated().sorted {
            let leftDistance = editDistance(original.lowercased(), $0.element.lowercased())
            let rightDistance = editDistance(original.lowercased(), $1.element.lowercased())
            return leftDistance == rightDistance ? $0.offset < $1.offset : leftDistance < rightDistance
        }.map(\.element)
    }

    private func isConfidentSpellingFix(from original: String, to replacement: String) -> Bool {
        guard original.count >= 4 else { return false }
        return editDistance(original.lowercased(), replacement.lowercased()) == 1
    }

    private func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1]
            for (j, right) in b.enumerated() {
                current.append(min(current[j] + 1, previous[j + 1] + 1,
                                   previous[j] + (left == right ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }

    private func clearSpellingSuggestion() {
        spellingSuggestion = nil
        onSpellingSuggestion?(nil)
    }

    private func isInputAllowed() -> Bool {
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedBundleIDs.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame }) {
            return false
        }
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue else { return true }
        let focused = unsafeDowncast(focusedValue, to: AXUIElement.self)
        var subroleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute as CFString, &subroleValue) == .success,
           let subrole = subroleValue as? String,
           subrole == kAXSecureTextFieldSubrole as String {
            return false
        }
        return true
    }

    private func switchLayout(to layout: Layout) {
        guard Layout.current != layout else { return }
        layout.activate()
        if soundEnabled {
            NSSound(named: NSSound.Name("Tink"))?.play()
        }
    }

    /// Uses the full dictionaries already installed with macOS. A replacement is
    /// accepted only when the typed form is unknown in its alphabet while the
    /// keyboard-layout conversion is a real word in the target language.
    private func systemDictionarySuggestion(for original: String, converted: String) -> (String, Layout)? {
        guard original.count >= 2, converted.allSatisfy(\.isLetter) else { return nil }
        let originalIsLatin = original.unicodeScalars.allSatisfy(\.isASCII)
        if originalIsLatin {
            let sourceKnown = isKnown(original, languages: ["en_US", "de_DE"])
            let targetKnown = isKnown(converted, languages: ["ru_RU"])
            return !sourceKnown && targetKnown ? (converted, .russian) : nil
        } else {
            let sourceKnown = isKnown(original, languages: ["ru_RU"])
            guard !sourceKnown else { return nil }
            if isKnown(converted, languages: ["en_US"]) { return (converted, .abc) }
            if isKnown(converted, languages: ["de_DE"]) { return (converted, .german) }
            return nil
        }
    }

    private func isKnown(_ word: String, languages: [String]) -> Bool {
        for language in languages {
            let misspelled = NSSpellChecker.shared.checkSpelling(
                of: word,
                startingAt: 0,
                language: language,
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: nil
            )
            if misspelled.location == NSNotFound { return true }
        }
        return false
    }

    private func replaceLastWord(with replacement: String, trailing: String, automatic: Bool) {
        let original = word
        injecting = true
        postBackspaces(original.count + trailing.count)
        postText(replacement + trailing)
        injecting = false
        lastReplacement = (original, replacement, trailing, automatic)
        word = ""
    }

    private func postBackspaces(_ count: Int) {
        for _ in 0..<count {
            let down = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: true)
            down?.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventMarker)
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: false)
            up?.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventMarker)
            up?.post(tap: .cghidEventTap)
        }
    }

    private func postText(_ text: String) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        event?.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventMarker)
        var units = Array(text.utf16)
        event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        event?.post(tap: .cghidEventTap)
    }
}

@MainActor
final class SpellingSuggestionPanel: NSPanel {
    private let suggestionLabel = NSTextField(labelWithString: "")
    private let applyButton = NSButton(title: "Tab — принять", target: nil, action: nil)
    private var applyAction: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 270, height: 48),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let effect = NSVisualEffectView(frame: contentView?.bounds ?? .zero)
        effect.autoresizingMask = [.width, .height]
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 11
        effect.layer?.masksToBounds = true
        contentView = effect

        suggestionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        suggestionLabel.lineBreakMode = .byTruncatingMiddle
        suggestionLabel.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(suggestionLabel)

        applyButton.bezelStyle = .rounded
        applyButton.controlSize = .small
        applyButton.target = self
        applyButton.action = #selector(apply)
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(applyButton)

        NSLayoutConstraint.activate([
            suggestionLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 13),
            suggestionLabel.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
            applyButton.leadingAnchor.constraint(greaterThanOrEqualTo: suggestionLabel.trailingAnchor, constant: 10),
            applyButton.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -9),
            applyButton.centerYAnchor.constraint(equalTo: effect.centerYAnchor)
        ])
    }

    func show(suggestion: String, apply: @escaping () -> Void) {
        suggestionLabel.stringValue = "«\(suggestion)»  ·  Esc — скрыть"
        applyAction = apply
        setFrameOrigin(originNearCaret())
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
        applyAction = nil
    }

    @objc private func apply() {
        applyAction?()
        dismiss()
    }

    private func originNearCaret() -> NSPoint {
        guard let caret = focusedCaretBounds() else {
            let mouse = NSEvent.mouseLocation
            return NSPoint(x: mouse.x + 8, y: mouse.y - frame.height - 8)
        }
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        var point = NSPoint(x: caret.minX, y: primaryTop - caret.maxY - frame.height - 7)
        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.insetBy(dx: -100, dy: -100).contains(point) }) {
            point.x = min(max(point.x, screen.visibleFrame.minX + 6), screen.visibleFrame.maxX - frame.width - 6)
            if point.y < screen.visibleFrame.minY { point.y = primaryTop - caret.minY + 7 }
        }
        return point
    }

    private func focusedCaretBounds() -> CGRect? {
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue else { return nil }
        let focused = unsafeDowncast(focusedValue, to: AXUIElement.self)
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue else { return nil }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focused, kAXBoundsForRangeParameterizedAttribute as CFString, rangeValue, &boundsValue
        ) == .success, let boundsValue else { return nil }
        var bounds = CGRect.zero
        guard AXValueGetValue(unsafeDowncast(boundsValue, to: AXValue.self), .cgRect, &bounds) else { return nil }
        return bounds
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = InputMonitor()
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var soundItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var spellingModeItem: NSMenuItem!
    private var spellingSuggestionItem: NSMenuItem!
    private var suggestionResetWork: DispatchWorkItem?
    private let spellingPanel = SpellingSuggestionPanel()
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        if let iconURL = Bundle.main.url(forResource: "LangPilotIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "LangPilot")
        statusItem.button?.image?.isTemplate = true
        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "Автокоррекция включена", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        soundItem = NSMenuItem(title: "Звук при переключении", action: #selector(toggleSound), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = monitor.soundEnabled ? .on : .off
        menu.addItem(soundItem)
        spellingModeItem = NSMenuItem(title: monitor.spellingMode.title, action: #selector(toggleSpellingMode), keyEquivalent: "")
        spellingModeItem.target = self
        menu.addItem(spellingModeItem)
        spellingSuggestionItem = NSMenuItem(title: "Нет предложений", action: #selector(applySpellingSuggestion), keyEquivalent: "s")
        spellingSuggestionItem.keyEquivalentModifierMask = [.command, .option]
        spellingSuggestionItem.target = self
        spellingSuggestionItem.isEnabled = false
        menu.addItem(spellingSuggestionItem)
        launchAtLoginItem = NSMenuItem(title: "Запускать вместе с macOS", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        let settings = NSMenuItem(title: "Настройки…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let correct = NSMenuItem(title: "Исправить последнее слово", action: #selector(correct), keyEquivalent: "l")
        correct.keyEquivalentModifierMask = [.command, .option]
        correct.target = self
        menu.addItem(correct)
        let undo = NSMenuItem(title: "Отменить последнюю замену", action: #selector(undo), keyEquivalent: "z")
        undo.keyEquivalentModifierMask = [.command, .option]
        undo.target = self
        menu.addItem(undo)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Завершить LangPilot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        monitor.onSpellingSuggestion = { [weak self] suggestion in
            self?.showSpellingSuggestion(suggestion)
        }

        configureLaunchAtLogin()

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        let inputGranted = CGPreflightListenEventAccess() || CGRequestListenEventAccess()
        guard accessibilityGranted, inputGranted, monitor.start() else {
            statusItem.button?.title = "!"
            toggleItem.title = "Нет доступа к вводу"
            toggleItem.isEnabled = false
            let alert = NSAlert()
            alert.messageText = "LangPilot не получает нажатия клавиш"
            var missing: [String] = []
            if !accessibilityGranted { missing.append("Универсальный доступ") }
            if !inputGranted { missing.append("Мониторинг ввода") }
            alert.informativeText = "В Системных настройках → Конфиденциальность и безопасность разрешите LangPilot: \(missing.joined(separator: " и ")). Затем полностью завершите и снова откройте приложение. Значок ЯA! означает, что доступ ещё не получен."
            alert.runModal()
            return
        }
    }

    @objc private func toggle() {
        monitor.enabled.toggle()
        toggleItem.title = monitor.enabled ? "Автокоррекция включена" : "Автокоррекция выключена"
        statusItem.button?.alphaValue = monitor.enabled ? 1.0 : 0.45
    }
    @objc private func toggleSound() {
        monitor.soundEnabled.toggle()
        soundItem.state = monitor.soundEnabled ? .on : .off
        if monitor.soundEnabled { NSSound(named: NSSound.Name("Tink"))?.play() }
    }
    @objc private func toggleSpellingMode() {
        monitor.spellingMode = monitor.spellingMode.next
        spellingModeItem.title = monitor.spellingMode.title
        if monitor.spellingMode == .off { showSpellingSuggestion(nil) }
    }
    @objc private func applySpellingSuggestion() { monitor.applySpellingSuggestion() }

    private func showSpellingSuggestion(_ suggestion: String?) {
        suggestionResetWork?.cancel()
        guard let suggestion else {
            spellingSuggestionItem.title = "Нет предложений"
            spellingSuggestionItem.isEnabled = false
            spellingPanel.dismiss()
            return
        }
        spellingSuggestionItem.title = "Исправить на «\(suggestion)»"
        spellingSuggestionItem.isEnabled = true
        spellingPanel.show(suggestion: suggestion) { [weak self] in
            self?.monitor.applySpellingSuggestion()
        }
        let work = DispatchWorkItem { [weak self] in self?.monitor.dismissSpellingSuggestion() }
        suggestionResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + monitor.suggestionDuration, execute: work)
    }
    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            updateLaunchAtLoginMenu()
        } catch {
            showLaunchAtLoginError(error)
        }
    }

    private func configureLaunchAtLogin() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "launchAtLoginConfigured") {
            defaults.set(true, forKey: "launchAtLoginConfigured")
            if SMAppService.mainApp.status != .enabled {
                do { try SMAppService.mainApp.register() }
                catch { showLaunchAtLoginError(error) }
            }
        }
        updateLaunchAtLoginMenu()
    }

    private func updateLaunchAtLoginMenu() {
        let status = SMAppService.mainApp.status
        launchAtLoginItem.state = status == .enabled ? .on : .off
        launchAtLoginItem.toolTip = status == .requiresApproval
            ? "Нужно разрешить в Systemeinstellungen → Allgemein → Anmeldeobjekte & Erweiterungen"
            : nil
    }

    private func showLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Не удалось включить автозапуск"
        alert.informativeText = "Переместите LangPilot в Programme и разрешите его в Systemeinstellungen → Allgemein → Anmeldeobjekte & Erweiterungen.\n\n\(error.localizedDescription)"
        alert.runModal()
        updateLaunchAtLoginMenu()
    }
    @objc private func openSettings() {
        if settingsController == nil { settingsController = SettingsWindowController(monitor: monitor) }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func correct() { monitor.correctLastManually() }
    @objc private func undo() { monitor.undo() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
