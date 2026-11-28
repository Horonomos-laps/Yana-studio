import AppKit
import CoreText
import SwiftUI

// The menu bar item's picture: the word "Yana" in the rounded system face, with the seven colours of RainbowText
// drifting through the letters. The numbers show only in the panel that opens from it.

enum MenuBarLabel {
	private static let height: CGFloat = 18, textSize: CGFloat = 14.5
	static let framesPerSecond = 8.0    // every new picture costs processor time, and this one always runs
	private static let pixelsPerPoint: CGFloat = 2
	static let frameCount = Int(RainbowText.loopSeconds * framesPerSecond)

	static var font: NSFont {
		let system = NSFont.systemFont(ofSize: textSize, weight: .heavy)
		guard let rounded = system.fontDescriptor.withDesign(.rounded),
		      let font = NSFont(descriptor: rounded, size: textSize) else { return system }
		return font
	}

	// One picture per step of the loop, made once. Frame 0 is also the still picture.
	static let frames: [NSImage] = (0 ..< frameCount).map { image(phase: Double($0) / Double(frameCount)) }

	// With the panel closed, the colours run one loop and then rest, because running all the time keeps a processor
	// busy. A loop starts and ends on frame 0, so the rest has no jump.
	static let restSeconds = 12.0

	// Which frame shows t seconds after an arbitrary start.
	static func frame(at t: Double, always: Bool) -> Int {
		let period = RainbowText.loopSeconds + restSeconds
		let wrapped = t.truncatingRemainder(dividingBy: period)
		if !always, (wrapped < 0 ? wrapped + period : wrapped) >= RainbowText.loopSeconds { return 0 }
		return min(frameCount - 1, Int(RainbowText.phase(at: always ? t : wrapped) * Double(frameCount)))
	}

	static func image(phase: Double) -> NSImage {
		let title = NSAttributedString(string: "Yana", attributes: [.font: font])
		let width = ceil(title.size().width)
		let size = NSSize(width: width, height: height)
		let image = NSImage(size: size)
		// Painted once into pixels, so showing a frame again does not redraw the letters.
		if let pixels = NSBitmapImageRep(
			bitmapDataPlanes: nil, pixelsWide: Int(width * pixelsPerPoint), pixelsHigh: Int(height * pixelsPerPoint),
			bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
			bytesPerRow: 0, bitsPerPixel: 0) {
			pixels.size = size
			NSGraphicsContext.saveGraphicsState()
			NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: pixels)
			draw(title, width: width, phase: phase)
			NSGraphicsContext.restoreGraphicsState()
			image.addRepresentation(pixels)
		}
		image.isTemplate = false
		image.accessibilityDescription = "Yana"
		return image
	}

	// The letters become the clipping shape and the sliding rainbow is painted through them.
	private static func draw(_ title: NSAttributedString, width: CGFloat, phase: Double) {
		let stops = RainbowText.stops()
		var locations = stops.map { CGFloat($0.location) }
		guard let context = NSGraphicsContext.current?.cgContext,
		      let gradient = NSGradient(colors: stops.map { NSColor($0.color) }, atLocations: &locations,
		                                colorSpace: .sRGB) else { return }
		let line = CTLineCreateWithAttributedString(title)
		var ascent: CGFloat = 0, descent: CGFloat = 0
		_ = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
		let ends = RainbowText.points(phase: phase)
		context.saveGState()
		context.textMatrix = .identity
		context.textPosition = CGPoint(x: 0, y: (height - ascent - descent) / 2 + descent)
		context.setTextDrawingMode(.clip)
		CTLineDraw(line, context)
		gradient.draw(from: NSPoint(x: ends.start.x * width, y: 0), to: NSPoint(x: ends.end.x * width, y: 0), options: [])
		context.restoreGState()
	}
}
