import AppKit
import SwiftUI

// A reply drawn as blocks (MarkdownBlocks): fenced code in a framed, monospaced box with its language and a copy
// button, headings sized by level, and the rest as text with inline Markdown. Everything stays selectable.

struct RichText: View {
	let text: String

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			ForEach(Array(MarkdownBlocks.parse(text).enumerated()), id: \.offset) { _, block in
				switch block {
				case .text(let value):
					Text(Self.inline(MarkdownBlocks.bulleted(value))).font(.system(size: 14)).foregroundStyle(FB.text)
						.frame(maxWidth: .infinity, alignment: .leading)
				case .heading(let level, let title):
					Text(Self.inline(title)).font(.system(size: Self.headingSize(level), weight: .bold)).foregroundStyle(FB.text)
						.frame(maxWidth: .infinity, alignment: .leading).padding(.top, level <= 2 ? 6 : 2)
				case .code(let language, let code, _):
					CodeBlock(language: language, code: code)
				}
			}
		}
		.textSelection(.enabled)
	}

	private static func headingSize(_ level: Int) -> CGFloat {
		switch level {
		case 1: return 21
		case 2: return 18
		case 3: return 16
		default: return 14
		}
	}

	private static func inline(_ text: String) -> AttributedString {
		let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
		return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
	}
}

struct CodeBlock: View {
	let language: String
	let code: String
	@State private var copied = false

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			HStack(spacing: 6) {
				Text(language.isEmpty ? L("code.label") : language).font(.fbCaption).foregroundStyle(FB.textSecondary)
				Spacer(minLength: 8)
				Button(action: copy) {
					HStack(spacing: 4) {
						FBIcon(name: copied ? "check" : "copy", size: 12, color: copied ? FB.successText : FB.textSecondary)
						Text(copied ? L("code.copied") : L("code.copy")).font(.fbCaption).foregroundStyle(copied ? FB.successText : FB.textSecondary)
					}
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 12).padding(.vertical, 6)
			.background(FB.surfaceSecondary)
			// Code that fits is drawn as it is; a long line scrolls sideways instead of wrapping, so indentation stays readable.
			ViewThatFits(in: .horizontal) {
				codeText.padding(12).frame(maxWidth: .infinity, alignment: .leading)
				ScrollView(.horizontal, showsIndicators: false) { codeText.padding(12) }
			}
		}
		.background(FB.surfaceTertiary)
		.clipShape(RoundedRectangle(cornerRadius: 10))
		.overlay(RoundedRectangle(cornerRadius: 10).stroke(FB.divider, lineWidth: 1))
	}

	private var codeText: some View {
		Text(code.isEmpty ? " " : code).font(CodeFont.font(name: AppSettings.shared.codeFontName, size: AppSettings.shared.codeFontSize)).foregroundStyle(FB.text)
			.fixedSize(horizontal: true, vertical: true)
	}

	private func copy() {
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(code, forType: .string)
		copied = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
	}
}
