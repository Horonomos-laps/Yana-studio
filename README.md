<h1 align="center">Yana Studio</h1>

<h3 align="center">One window for a real project. Yana decides what the AI may do.</h3>

<p align="center">
  The desktop apps of the Yana ecosystem: files, terminals, chat and tasks<br>
  in one workspace, with every model request governed by the Yana runtime.
</p>

<p align="center">
  <a href="https://github.com/Horonomos-laps/Yana-studio/releases/latest"><img src="https://img.shields.io/github/v/release/Horonomos-laps/Yana-studio?label=release&color=8b5cf6&style=flat" alt="Latest release" height="20"></a>
  <a href="https://github.com/Horonomos-laps/Yana-studio/actions/workflows/js-tests.yml"><img src="https://img.shields.io/github/actions/workflow/status/Horonomos-laps/Yana-studio/js-tests.yml?branch=main&label=tests&style=flat" alt="Studio tests" height="20"></a>
  <img src="https://img.shields.io/badge/macOS-SwiftUI-000000?style=flat&logo=apple" alt="macOS app in SwiftUI" height="20">
  <img src="https://img.shields.io/badge/Studio-Electron-47848f?style=flat&logo=electron" alt="Studio on Electron" height="20">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache--2.0-2563eb?style=flat" alt="Apache 2.0 license" height="20"></a>
</p>

<p align="center">
  <a href="https://github.com/Horonomos-laps/Yana-AI"><img src="https://img.shields.io/badge/Yana--AI-runtime_and_rules-475569?style=flat" alt="Yana-AI" height="20"></a>
  <a href="https://github.com/Horonomos-laps/yana-web"><img src="https://img.shields.io/badge/yana--web-website_and_web_app-475569?style=flat" alt="yana-web" height="20"></a>
  <img src="https://img.shields.io/badge/Yana--studio-you_are_here-8b5cf6?style=flat" alt="Yana-studio, this repository" height="20">
</p>

<p align="center">
  <a href="#download">Download</a> ·
  <a href="#the-apps">The apps</a> ·
  <a href="#build-from-source">Build</a> ·
  <a href="#status">Status</a> ·
  <a href="https://yana.vutam.link">Website</a>
</p>

<p align="center">
  <sub>
    <a href="https://github.com/Horonomos-laps/Yana-AI/blob/main/CODE_OF_CONDUCT.md">Code of conduct</a> ·
    <a href="https://github.com/Horonomos-laps/Yana-AI/blob/main/CONTRIBUTING.md">Contributing</a> ·
    <a href="LICENSE">Apache-2.0 license</a> ·
    <a href="https://github.com/Horonomos-laps/Yana-AI/blob/main/SECURITY.md">Security policy</a>
  </sub>
</p>

<br>

<table>
  <tr>
    <td align="center" width="25%"><h3>2</h3><sub>apps: Yana and<br>Yana Studio</sub></td>
    <td align="center" width="25%"><h3>1</h3><sub>download holds<br>both apps</sub></td>
    <td align="center" width="25%"><h3>1</h3><sub>runtime for every<br>model request</sub></td>
    <td align="center" width="25%"><h3>14+</h3><sub>macOS, on<br>Apple Silicon</sub></td>
  </tr>
</table>

<!-- IMAGE: hero, the Studio window with the wallpaper showing through the terminal -->

## Download

1. Get `Yana-<version>.dmg` from the [latest release](https://github.com/Horonomos-laps/Yana-studio/releases/latest).
2. Open it and drag **Yana** into Applications.
3. The first time, right-click Yana and choose **Open**, or use **System Settings → Privacy & Security → Open Anyway**.

It needs macOS 14 or later on Apple Silicon. The app is ad-hoc signed and **not notarized**
by Apple, which is why macOS asks you to confirm. Each release lists the SHA-256 of its
files. From version 1.1.0 on, the **Update** button inside the app downloads the new
version, checks its signature and replaces the app.

## The apps

One download holds two applications.

| App | What it is for |
| --- | --- |
| **Yana** | Native SwiftUI app: chat with a model, projects, approvals, usage, the notch and the menu bar |
| **Yana Studio** | Code editor built on Code-OSS, with the Yana panel, terminals and an animated wallpaper |

- **Approvals.** Commands wait for your answer. Auto Mode allows a short list of safe commands, and keeps its permissions outside the project folder.
- **Two apps, one setup.** Open Yana Studio from Yana on the folder you are working in. An API key saved once is stored in the macOS Keychain and used by both. Each app keeps its own chat history.
- **Notch.** Whether Claude Code or Codex is working or waiting for you, music controls, a file shelf, clipboard history, timers and notes.
- **Menu bar.** CPU, GPU, memory, disk and temperature, plus what Yana itself is using. Closing the window keeps Yana running there.
- **Wallpaper.** Animated scenes or your own picture or video behind the whole editor, including the terminal.

<!-- IMAGE: approval prompt -->
<!-- IMAGE: notch -->

## Status

- Released for **Apple Silicon Macs only**.
- Auto Mode needs `yana-rt` 1.5.6 or later. The commands it runs are **not isolated** from your Mac.
- Control levels run from 1 to 5. The runtime reports how far they are enforced; levels above that only record what they would have approved.
- Clipboard history in the notch is stored **without encryption**.
- Temperature is read through a private Apple interface and was tried on one M4 Mac.
- With *Open at login* on, the main window still opens.

## Source layout

| Directory | What it holds |
| --- | --- |
| [`yana-app/`](yana-app) | The native macOS app. Its updater reads this repository's `app-v*` releases. |
| [`yana-ide/`](yana-ide) | Yana's patches, theme, wallpaper and extension applied on top of Code-OSS. It holds no upstream code. This is the editor shipped as Yana Studio. |
| [`yana-studio/`](yana-studio) | An earlier Electron workspace. Its tests still run in CI. |

The files at the root (`src/`, `Cargo.toml`, `DESIGN.md`, `UI_ENGINES.md`, `reference/`)
are a terminal interface prototype that runs on mock data. It is not part of the app.

## Build from source

The macOS app:

```bash
git clone https://github.com/Horonomos-laps/Yana-studio.git
cd Yana-studio/yana-app
swift build
swift test
```

For the editor, follow [`yana-ide/README.md`](yana-ide/README.md). Both apps need a
`yana-rt` binary from [Yana-AI](https://github.com/Horonomos-laps/Yana-AI).

## The Yana ecosystem

| Repository | Role |
| --- | --- |
| **[Yana-AI](https://github.com/Horonomos-laps/Yana-AI)** | The runtime `yana-rt`, governance rules and hooks, the CLI, agents and skills |
| **[yana-web](https://github.com/Horonomos-laps/yana-web)** | The website, and a web app you run on your own machine |
| **Yana-studio** (this repository) | The macOS app and Yana Studio |

---

Original concept, product direction, architecture and interaction design by **Vũ Văn Tâm**.
AI tools may assist with implementation, testing, documentation and review; accepted
changes stay under maintainer control.

[Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Code of conduct](CODE_OF_CONDUCT.md) · [Apache 2.0](LICENSE)
