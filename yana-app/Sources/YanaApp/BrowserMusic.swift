import Foundation

// Music playing in a web page, such as YouTube or YouTube Music in Chrome, Safari, Brave, Edge or Arc. The browsers do
// not tell other apps what is playing, but they can run a line of JavaScript in a tab when asked through AppleScript,
// and the page's own video element knows the title, the time and whether it plays. This is an official route, with two
// limits: macOS asks once to let Yana control the browser, and the browser has a switch that must be on ("Allow
// JavaScript from Apple Events"). Only pages of YouTube are read.

enum BrowserMusic {
	static let chromeFamily = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Arc"]
	static let safari = "Safari"

	enum Command { case playPause, next, previous }

	enum Problem: Equatable {
		case automationRefused            // macOS did not allow controlling the browser
		case javascriptOff(app: String)   // the browser's switch for JavaScript from Apple Events is off
	}

	// Reads the page: state, title, channel, duration and position in seconds, and the thumbnail. No double quotes,
	// so it can sit inside an AppleScript string. The pieces are joined by character 31, as for the other players.
	static let readJS = "(function(){var v=document.querySelector('video');if(!v)return '';var id='';"
		+ "try{id=new URL(location.href).searchParams.get('v')||''}catch(e){}"
		+ "var ch=document.querySelector('ytd-channel-name a, #owner #channel-name a, ytmusic-player-bar .byline');"
		+ "var d=String.fromCharCode(31);"
		+ "return [v.paused?'paused':'playing',document.title.replace(/ - YouTube( Music)?$/,''),ch?ch.textContent.trim():'',"
		+ "v.duration||0,v.currentTime||0,id?'https://i.ytimg.com/vi/'+id+'/hqdefault.jpg':''].join(d);})()"

	static func js(for command: Command) -> String {
		switch command {
		case .playPause: "(function(){var v=document.querySelector('video');if(v){v.paused?v.play():v.pause();}})()"
		case .next: "(function(){var b=document.querySelector('.ytp-next-button, .next-button');if(b)b.click();})()"
		case .previous:
			"(function(){var b=document.querySelector('.ytp-prev-button, .previous-button');"
				+ "if(b&&getComputedStyle(b).display!=='none'){b.click();}else{var v=document.querySelector('video');if(v)v.currentTime=0;}})()"
		}
	}

	// Runs a JavaScript line in the first YouTube tab of the app and returns its text. Says nothing when the app is not
	// running, so asking never launches it.
	static func script(app: String, bundle: String, js: String) -> String {
		let run = app == safari ? "do JavaScript \"\(js)\" in t" : "execute t javascript \"\(js)\""
		return """
		if application id "\(bundle)" is running then
			tell application id "\(bundle)"
				repeat with w in windows
					repeat with t in tabs of w
						set u to URL of t
						if u contains "youtube.com/watch" or u contains "music.youtube.com" then
							set r to \(run)
							if r is not missing value and r is not "" then return r
						end if
					end repeat
				end repeat
			end tell
		end if
		return ""
		"""
	}

	// What a failed AppleScript call means, from its error number and message.
	static func problem(code: Int, message: String, app: String) -> Problem? {
		if code == -1743 { return .automationRefused }
		let lower = message.lowercased()
		if lower.contains("javascript") && (lower.contains("apple events") || lower.contains("applescript") || lower.contains("turned off")) {
			return .javascriptOff(app: app)
		}
		return nil
	}

	// Where the switch is, for the message shown on the card.
	static func switchHint(app: String) -> String {
		app == safari ? "Safari → Develop → Allow JavaScript from Apple Events" : "\(app) → View → Developer → Allow JavaScript from Apple Events"
	}
}
