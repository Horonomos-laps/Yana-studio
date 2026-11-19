import SwiftUI

// The composer chip for how much the agent may do without asking. It replaces the older "Auto" chip when the
// installed yana-rt has the control levels and the away mode; the older chip stays for a runtime that does not.
// One popover: the level as five dots (like the effort slider), then the away mode, then what is waiting.

enum LevelText {
	static func name(_ level: Int) -> String { L("level.\(level).name") }
	static func about(_ level: Int) -> String { L("level.\(level).about") }
}

// Five dots: the filled run is the level in force. A level yana-rt only observes is drawn in the warning color.
struct LevelDots: View {
	let state: LevelState
	let choose: (Int) -> Void

	var body: some View {
		HStack(spacing: 14) {
			ForEach(1 ... 5, id: \.self) { number in
				let filled = number <= state.level
				let current = number == state.level
				Circle()
					.fill(filled ? (number > state.enforcedUpTo ? FB.warningText : FB.primary) : FB.divider)
					.frame(width: current ? 18 : 11, height: current ? 18 : 11)
					.overlay(Circle().stroke(current ? FB.primaryBorder : .clear, lineWidth: 2))
					.frame(width: 28, height: 28)
					.contentShape(Rectangle())
					.onTapGesture { choose(number) }
					.help("\(number). \(LevelText.name(number))")
			}
		}
		.animation(FB.fast, value: state.level)
	}
}

struct AwayChip: View {
	@ObservedObject var store: AutonomyStore
	let folder: String
	@State private var open = false
	@State private var awayLevel = 4
	@State private var budget = AutonomyStore.defaultBudget

	private var remaining: String {
		guard let until = store.away.expiresAt else { return "" }
		let minutes = max(Int(until.timeIntervalSinceNow / 60), 0)
		return String(format: "%d:%02d", minutes / 60, minutes % 60)
	}

	var body: some View {
		Chip(
			icon: store.away.active ? "clock" : "shield",
			title: store.away.active ? "\(L("away.on")) \(remaining)" : "\(L("mode.control")) \(store.level.level)",
			trailing: "chevron-down")
			.overlay(Capsule().stroke(store.away.active ? FB.primary : .clear, lineWidth: 1.5))
			.help(L("mode.help"))
			.onTapGesture { store.refresh(folder: folder); open = true }
			.popover(isPresented: $open, arrowEdge: .top) { menu }
			.task { store.refresh(folder: folder) }
	}

	private var menu: some View {
		VStack(alignment: .leading, spacing: 12) {
			levelSection
			Divider()
			awaySection
			if !store.parked.isEmpty { Divider(); parkedSection }
			if let error = store.error {
				Text(error).font(.fbCaption).foregroundStyle(FB.errorText).fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(16).frame(width: 440)
	}

	private var levelSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(L("mode.control")).font(.fbHeading5).foregroundStyle(FB.text)
			LevelDots(state: store.level) { store.setLevel($0) }
			Text("\(store.level.level). \(LevelText.name(store.level.level))").font(.fbBodyMedium).foregroundStyle(FB.text)
			Text(LevelText.about(store.level.level)).font(.fbCaption).foregroundStyle(FB.textSecondary)
				.fixedSize(horizontal: false, vertical: true)
			Text(store.level.observedOnly ? L("mode.observed") : L("mode.enforced")).font(.fbCaption)
				.foregroundStyle(store.level.observedOnly ? FB.warningText : FB.successText)
				.fixedSize(horizontal: false, vertical: true)
			if let problem = store.level.problem {
				Text(problem).font(.fbCaption).foregroundStyle(FB.errorText).fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private var awaySection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(L("away.title")).font(.fbHeading5).foregroundStyle(FB.text)
			Text(L("away.explain")).font(.fbCaption).foregroundStyle(FB.textSecondary).fixedSize(horizontal: false, vertical: true)
			if store.away.active {
				Text("\(L("away.on")) \(remaining) · \(L("away.used")) \(store.away.used) / \(store.away.budget) · \(L("away.level")) \(store.away.level)")
					.font(.fbBody).foregroundStyle(FB.text)
				FBButton(title: L("away.stop"), variant: .danger) { store.stopAway() }
			} else {
				Picker(L("away.level"), selection: $awayLevel) {
					ForEach(AutonomyStore.awayLevels, id: \.self) { Text("\($0). \(LevelText.name($0))").tag($0) }
				}
				Stepper(value: $budget, in: AutonomyStore.budgetRange, step: 10) {
					Text("\(L("away.budget")): \(budget)").font(.fbBody)
				}
				HStack {
					ForEach(AutonomyStore.durations, id: \.self) { minutes in
						FBButton(title: minutes < 60 ? "\(minutes) \(L("auto.min"))" : "\(minutes / 60) \(L("auto.hour"))", variant: .secondary) {
							store.startAway(minutes: minutes, budget: budget, level: awayLevel)
						}
					}
				}
			}
		}
	}

	private var parkedSection: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("\(L("away.parked")) (\(store.parked.count))").font(.fbHeading5).foregroundStyle(FB.text)
			// A few items fit as they are; scrolling only when there are many.
			if store.parked.count > Self.scrollAfter {
				ScrollView { parkedRows }.frame(maxHeight: 160)
			} else {
				parkedRows
			}
			FBButton(title: L("away.clear"), variant: .secondary) { store.clearParked() }
		}
	}

	private static let scrollAfter = 3

	private var parkedRows: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(store.parked) { item in
				VStack(alignment: .leading, spacing: 2) {
					Text(item.summary.isEmpty ? item.capability : item.summary)
						.font(.system(size: 12, design: .monospaced)).foregroundStyle(FB.text).lineLimit(2)
					Text(item.reason).font(.fbCaption).foregroundStyle(FB.textSecondary).fixedSize(horizontal: false, vertical: true)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
