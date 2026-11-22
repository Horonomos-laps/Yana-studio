import XCTest
@testable import YanaApp

final class PersonalStyleTests: XCTestCase {
	private func defaults() -> UserDefaults {
		let name = "yana.tests.style.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		return d
	}

	private func tempFolder() throws -> String {
		let dir = FileManager.default.temporaryDirectory.appendingPathComponent("yana-agents-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		return dir.path
	}

	// MARK: style

	func testNothingIsSentWhileEveryChoiceIsOnItsDefault() {
		XCTAssertTrue(PersonalStyle().sentences.isEmpty)
		XCTAssertTrue(PersonalStyle().isDefault)
		XCTAssertNil(Personalization.instruction(defaults()), "an untouched install adds nothing to the request")
	}

	func testEachChoiceAddsExactlyOneSentence() {
		var style = PersonalStyle(); style.tone = .candid
		XCTAssertEqual(style.sentences.count, 1)
		for level in [StyleLevel.less, .more] {
			var s = PersonalStyle(); s.warm = level; XCTAssertEqual(s.sentences.count, 1, "warm \(level)")
			s = PersonalStyle(); s.enthusiastic = level; XCTAssertEqual(s.sentences.count, 1)
			s = PersonalStyle(); s.emoji = level; XCTAssertEqual(s.sentences.count, 1)
			s = PersonalStyle(); s.structure = level; XCTAssertEqual(s.sentences.count, 1)
		}
		var visual = PersonalStyle(); visual.visual = true
		XCTAssertEqual(visual.sentences.count, 1)
	}

	func testEveryToneButTheDefaultHasItsOwnSentence() {
		let sentences = BaseTone.allCases.compactMap(\.sentence)
		XCTAssertEqual(sentences.count, BaseTone.allCases.count - 1)
		XCTAssertEqual(Set(sentences).count, sentences.count)
		XCTAssertNil(BaseTone.standard.sentence)
	}

	func testOppositeChoicesSayOppositeThings() {
		var more = PersonalStyle(); more.emoji = .more
		var less = PersonalStyle(); less.emoji = .less
		XCTAssertNotEqual(more.sentences, less.sentences)
		XCTAssertTrue(less.sentences[0].lowercased().contains("not use emoji"))
	}

	func testTheStyleIsReadFromTheDefaultsAndReachesTheRequest() {
		let d = defaults()
		d.set(BaseTone.efficient.rawValue, forKey: PersonalStyle.toneKey)
		d.set(StyleLevel.less.rawValue, forKey: PersonalStyle.emojiKey)
		d.set(true, forKey: PersonalStyle.visualKey)
		let style = PersonalStyle.current(d)
		XCTAssertEqual(style.tone, .efficient); XCTAssertEqual(style.emoji, .less); XCTAssertTrue(style.visual)
		let text = Personalization.instruction(d) ?? ""
		XCTAssertTrue(text.contains("Reply style the user asked for"))
		for sentence in style.sentences { XCTAssertTrue(text.contains(sentence), sentence) }
	}

	func testAnUnknownStoredValueFallsBackToTheDefault() {
		let d = defaults()
		d.set("shouting", forKey: PersonalStyle.toneKey)
		d.set("lots", forKey: PersonalStyle.warmKey)
		XCTAssertTrue(PersonalStyle.current(d).isDefault)
	}

	func testStyleSitsBetweenWhatYanaKnowsAndTheStandingRules() {
		let d = defaults()
		d.set("Dat", forKey: Personalization.nameKey)
		d.set("Always answer in Vietnamese.", forKey: Personalization.rulesKey)
		d.set(BaseTone.friendly.rawValue, forKey: PersonalStyle.toneKey)
		let text = Personalization.instruction(d) ?? ""
		let name = text.range(of: "Dat")!.lowerBound, style = text.range(of: "Reply style")!.lowerBound
		let rules = text.range(of: "Standing instructions")!.lowerBound
		XCTAssertTrue(name < style && style < rules)
	}

	func testTheKeysAreDistinctAndTheStringsExist() {
		XCTAssertEqual(Set(PersonalStyle.allKeys).count, PersonalStyle.allKeys.count)
		for row in personalStyleRows { XCTAssertFalse(row.vi.isEmpty || row.en.isEmpty || row.ko.isEmpty, row.key) }
		for tone in BaseTone.allCases { XCTAssertNotEqual(L("per.tone.\(tone.rawValue)"), "per.tone.\(tone.rawValue)") }
		for level in StyleLevel.allCases { XCTAssertNotEqual(L("per.level.\(level.rawValue)"), "per.level.\(level.rawValue)") }
		XCTAssertEqual(Set(allStringRows.map(\.key)).count, allStringRows.count)
	}

	// MARK: AGENTS.md

	func testTheFileIsReadWrittenAndKeptInTheProjectFolder() throws {
		let folder = try tempFolder()
		XCTAssertEqual(AgentsFile.read(workspace: folder)?.exists, false, "no file yet")
		try AgentsFile.save("# Rules\nUse tabs.\n", workspace: folder)
		let back = AgentsFile.read(workspace: folder)
		XCTAssertEqual(back?.text, "# Rules\nUse tabs.\n"); XCTAssertEqual(back?.exists, true)
		XCTAssertEqual(AgentsFile.url(workspace: folder)?.lastPathComponent, "AGENTS.md")
		XCTAssertEqual(AgentsFile.url(workspace: folder)?.deletingLastPathComponent().path, folder)
	}

	func testNothingIsWrittenWithoutARealFolderOrForAHugeText() throws {
		XCTAssertThrowsError(try AgentsFile.save("x", workspace: "/no/such/folder")) { XCTAssertEqual($0 as? AgentsFile.Failure, .noFolder) }
		XCTAssertThrowsError(try AgentsFile.save("x", workspace: "")) { XCTAssertEqual($0 as? AgentsFile.Failure, .noFolder) }
		let folder = try tempFolder()
		XCTAssertThrowsError(try AgentsFile.save(String(repeating: "a", count: AgentsFile.maxChars + 1), workspace: folder)) {
			XCTAssertEqual($0 as? AgentsFile.Failure, .tooLong)
		}
		XCTAssertEqual(AgentsFile.read(workspace: folder)?.exists, false, "a refused save leaves no file")
		XCTAssertNil(AgentsFile.read(workspace: "/no/such/folder"))
	}

	func testAFileThatIsNotTextIsTreatedAsEmptyNotACrash() throws {
		let folder = try tempFolder()
		try Data([0xFF, 0xFE, 0x00, 0x80]).write(to: URL(fileURLWithPath: folder).appendingPathComponent("AGENTS.md"))
		XCTAssertEqual(AgentsFile.read(workspace: folder)?.text, "")
	}

	func testTheFileNameCannotEscapeTheFolder() throws {
		let folder = try tempFolder()
		XCTAssertFalse(AgentsFile.fileName.contains("/"))
		XCTAssertFalse(AgentsFile.fileName.contains(".."))
		XCTAssertEqual(AgentsFile.url(workspace: folder)?.deletingLastPathComponent().standardizedFileURL.path, URL(fileURLWithPath: folder).standardizedFileURL.path)
	}
}
