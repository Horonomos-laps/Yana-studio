import SwiftUI

// First-run guide in the spirit of OneNotch's: one card, but each page has its own layout and colour and
// shows the real action (TourMedia: a screen recording when bundled, else a drawn demo of the real
// screen). Shown once at the first launch, again from Help > Yana guide and Settings > About.

struct TourPage: Identifiable {
	enum Layout { case hero, mediaLeft, mediaRight, mediaTop }
	let id: String
	let layout: Layout
	let tint: Color
	var badge: String? = nil
}

enum OnboardingTour {
	// The guide grew (chats, voice, shortcuts, the look). `seenKey` is for the current guide; `legacySeenKey` is the
	// one the first five pages set, so a person who finished those is shown only the new pages, once.
	static let legacySeenKey = "yana.onboarding.seen"
	static let seenKey = "yana.onboarding.seen.v2"
	static let pages: [TourPage] = [
		TourPage(id: "welcome", layout: .hero, tint: FB.primarySubtle),
		TourPage(id: "models", layout: .mediaLeft, tint: FB.surfaceTertiary),
		TourPage(id: "approve", layout: .mediaTop, tint: FB.warningSubtle),
		TourPage(id: "tools", layout: .mediaRight, tint: FB.successSubtle),
		TourPage(id: "memory", layout: .mediaTop, tint: FB.primarySubtle),
		TourPage(id: "chats", layout: .mediaLeft, tint: FB.primarySubtle, badge: "tour.new"),
		TourPage(id: "voice", layout: .mediaRight, tint: FB.warningSubtle, badge: "tour.new"),
		TourPage(id: "shortcuts", layout: .mediaTop, tint: FB.surfaceTertiary, badge: "tour.new"),
		TourPage(id: "look", layout: .mediaLeft, tint: FB.successSubtle, badge: "tour.new"),
	]
	static let cardSize = CGSize(width: 680, height: 500)

	static var shouldShowAtLaunch: Bool { !UserDefaults.standard.bool(forKey: seenKey) }
	static func markSeen() {
		UserDefaults.standard.set(true, forKey: seenKey)
		UserDefaults.standard.set(true, forKey: legacySeenKey)
	}

	// Where the guide opens: at the first new page for someone who saw the old guide, at the start otherwise.
	static func startIndex(legacySeen: Bool, seen: Bool, pages: [TourPage] = OnboardingTour.pages) -> Int {
		guard legacySeen, !seen else { return 0 }
		return pages.firstIndex { $0.badge != nil } ?? 0
	}
}

// The plugin store's own guide: shown on the first visit, and from the "?" button on the store page.
enum StoreTour {
	static let seenKey = "yana.storeTour.seen"
	static let pages: [TourPage] = [
		TourPage(id: "store-browse", layout: .mediaLeft, tint: FB.primarySubtle),
		TourPage(id: "store-sources", layout: .mediaRight, tint: FB.successSubtle),
		TourPage(id: "store-get", layout: .mediaTop, tint: FB.warningSubtle),
		TourPage(id: "store-installed", layout: .mediaLeft, tint: FB.surfaceTertiary),
	]
	static var shouldShow: Bool { !UserDefaults.standard.bool(forKey: seenKey) }
}

struct OnboardingTourView: View {
	// The app guide by default; other guides (the plugin store) pass their own pages and "seen" key.
	var pages: [TourPage] = OnboardingTour.pages
	var seenKey: String = OnboardingTour.seenKey
	let close: () -> Void
	// YANA_TOUR_PAGE=<n> opens page n (1-5) to check its look in the live window.
	@State private var index = ProcessInfo.processInfo.environment["YANA_TOUR_PAGE"]
		.flatMap(Int.init).map { min(max($0 - 1, 0), OnboardingTour.pages.count - 1) } ?? 0
	private var page: TourPage { pages[min(index, pages.count - 1)] }
	// Opens at the new pages for a person who already saw the first guide (OnboardingTour.startIndex).
	private func openAtNewPages() {
		guard seenKey == OnboardingTour.seenKey, ProcessInfo.processInfo.environment["YANA_TOUR_PAGE"] == nil else { return }
		let defaults = UserDefaults.standard
		index = OnboardingTour.startIndex(legacySeen: defaults.bool(forKey: OnboardingTour.legacySeenKey),
		                                  seen: defaults.bool(forKey: OnboardingTour.seenKey), pages: pages)
	}
	private var isLast: Bool { index >= pages.count - 1 }

	var body: some View {
		VStack(spacing: 0) {
			content.id(page.id).transition(.opacity)
			footer.padding(EdgeInsets(top: 0, leading: 28, bottom: 22, trailing: 24))
		}
		.frame(width: OnboardingTour.cardSize.width, height: OnboardingTour.cardSize.height)
		.background(FB.canvas)
		.onAppear(perform: openAtNewPages)
		.overlay(alignment: .topTrailing) {
			Button(action: finish) { Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)) }
				.buttonStyle(.plain).foregroundStyle(FB.textSecondary)
				.frame(width: 28, height: 28).background(Circle().fill(FB.surface.opacity(0.9)))
				.padding(12).help(L("tour.skip"))
		}
	}

	@ViewBuilder
	private var content: some View {
		switch page.layout {
		case .hero:
			VStack(spacing: 14) {
				media.frame(height: 230)
				RabbitLogo(cell: 2.2).padding(.top, 4)
				Text(L("tour.\(page.id).title")).font(.system(size: 30, weight: .bold)).foregroundStyle(FB.text)
				Text(L("tour.\(page.id).body")).font(.system(size: 14)).foregroundStyle(FB.textSecondary)
					.multilineTextAlignment(.center).frame(maxWidth: 520).fixedSize(horizontal: false, vertical: true)
				Spacer(minLength: 0)
			}
		case .mediaTop:
			VStack(alignment: .leading, spacing: 12) {
				media.frame(height: 250)
				texts.padding(.horizontal, 28)
				Spacer(minLength: 0)
			}
		case .mediaLeft, .mediaRight:
			HStack(spacing: 0) {
				if page.layout == .mediaLeft { media.frame(width: 360) }
				VStack(alignment: .leading, spacing: 12) {
					Spacer(minLength: 0)
					texts
					Spacer(minLength: 0)
				}
				.padding(.horizontal, 26)
				if page.layout == .mediaRight { media.frame(width: 360) }
			}
			.frame(maxHeight: .infinity)
		}
	}

	private var media: some View {
		ZStack {
			page.tint
			TourMedia(pageID: page.id).padding(22)
		}
		.clipped()
	}

	private var texts: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(L(page.badge ?? "tour.step")).font(.system(size: 11, weight: .bold)).foregroundStyle(FB.primaryText)
				.padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(FB.primarySubtle))
			Text(L("tour.\(page.id).title")).font(.system(size: 26, weight: .bold)).foregroundStyle(FB.text)
				.fixedSize(horizontal: false, vertical: true)
			Text(L("tour.\(page.id).body")).font(.system(size: 14)).foregroundStyle(FB.textSecondary)
				.fixedSize(horizontal: false, vertical: true)
		}
	}

	private var footer: some View {
		HStack(alignment: .center) {
			HStack(spacing: 6) {
				ForEach(pages.indices, id: \.self) { i in
					Capsule().fill(i == index ? FB.text : FB.borderStrong).frame(width: i == index ? 22 : 7, height: 7)
				}
			}
			Spacer()
			if index > 0 {
				Button(L("tour.back")) { withAnimation(.easeOut(duration: 0.2)) { index -= 1 } }
					.buttonStyle(.plain).foregroundStyle(FB.textSecondary).padding(.trailing, 8)
			}
			Button(action: next) {
				HStack(spacing: 6) {
					Text(L(isLast ? "tour.done" : "tour.next"))
					if !isLast { Image(systemName: "arrow.right") }
				}
				.font(.system(size: 14, weight: .semibold)).foregroundStyle(FB.onPrimary)
				.padding(.horizontal, 20).frame(height: 40)
				.background(Capsule().fill(FB.primary))
			}
			.buttonStyle(.plain)
			.keyboardShortcut(.defaultAction)
		}
		.frame(height: 48)
	}

	private func next() {
		if isLast { finish() } else { withAnimation(.easeOut(duration: 0.2)) { index += 1 } }
	}

	private func finish() {
		UserDefaults.standard.set(true, forKey: seenKey)
		close()
	}
}
