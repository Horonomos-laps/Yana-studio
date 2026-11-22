# Credits

## Ideas from notchd

Yana's notch feature is inspired by [notchd](https://github.com/notchd-app/notchd) (Apache License 2.0).
No notchd code is included. Yana's version is written from scratch; what is borrowed is the idea, listed here.

| Idea | Where it appears in notchd |
|---|---|
| A borderless, non-activating panel over the notch that lets clicks pass through outside its shape | Sources/Notchd/NotchController.swift |
| Measuring the notch from the screen's safe area and its two top areas; a small handle on screens without one | Sources/Notchd/NotchModel.swift |
| A spring that overshoots a little when opening, calmer when closing | Sources/Notchd/NotchModel.swift |
| Coding agents (Claude Code, Codex) reporting through small event files in a watched folder | Sources/Notchd/Agents.swift |
| Live activities that widen the closed notch, a glance line, and priorities between activities | README and Sources/Notchd/LiveActivities.swift |
| Open on hover after a short rest, a frosted open panel over a solid black closed pill | Sources/Notchd/NotchController.swift, NotchView.swift |
| A widget set in the open notch: music with controls, timers and a Pomodoro, to-do list, notes, clipboard history | README, Sources/Notchd/Widgets.swift, Timer.swift, Pomodoro.swift, Notes.swift, Clipboard.swift |
| Not closing while a text field has the keyboard | Sources/Notchd/NotchController.swift |

If code from notchd is ever copied, it will keep its license header and be marked here as copied.
