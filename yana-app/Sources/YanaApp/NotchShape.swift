import SwiftUI

// The silhouette: the top corners flare outward into the menu bar (concave), the bottom corners are rounded (convex).
// Both radii animate, so the shape morphs between looks instead of jumping.

struct NotchShape: Shape {
	var topRadius: CGFloat
	var bottomRadius: CGFloat

	var animatableData: AnimatablePair<CGFloat, CGFloat> {
		get { .init(topRadius, bottomRadius) }
		set { topRadius = newValue.first; bottomRadius = newValue.second }
	}

	func path(in rect: CGRect) -> Path {
		let w = rect.width, h = rect.height
		let t = max(0, min(topRadius, h, w / 2))   // a flare never reaches below the shape or past its middle
		let b = max(0, min(bottomRadius, h / 2, (w - 2 * t) / 2))
		var p = Path()
		p.move(to: CGPoint(x: rect.minX, y: rect.minY))
		p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t), control: CGPoint(x: rect.minX + t, y: rect.minY))
		p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
		p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY), control: CGPoint(x: rect.minX + t, y: rect.maxY))
		p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
		p.addQuadCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b), control: CGPoint(x: rect.maxX - t, y: rect.maxY))
		p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
		p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - t, y: rect.minY))
		p.closeSubpath()
		return p
	}
}

extension Animation {
	// Opening overshoots a little, closing is calmer, hovering is bouncy.
	static let notchOpen = Animation.spring(response: 0.42, dampingFraction: 0.68)
	static let notchClose = Animation.spring(response: 0.36, dampingFraction: 0.88)
	static let notchHover = Animation.spring(response: 0.3, dampingFraction: 0.55)
}
