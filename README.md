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
    <td align="center" width="25%"><h3>3</h3><sub>apps: macOS, Studio<br>and IDE</sub></td>
    <td align="center" width="25%"><h3>12</h3><sub>terminals in<br>one grid</sub></td>
    <td align="center" width="25%"><h3>1</h3><sub>runtime for every<br>model request</sub></td>
    <td align="center" width="25%"><h3>8 MiB</h3><sub>largest file<br>editable in place</sub></td>
  </tr>
</table>

## The Yana ecosystem

| Repository | Role |
| --- | --- |
| **[Yana-AI](https://github.com/Horonomos-laps/Yana-AI)** | Runtime `yana-rt`, governance rules and hooks, CLI, agents and skills |
| **[yana-web](https://github.com/Horonomos-laps/yana-web)** | The website at yana.vutam.link, and a local web app |
| **Yana-studio** (this repo) | Desktop apps: native macOS app, Yana Studio, Yana IDE |

The apps are the part you look at. They do not decide anything. Every model request
goes through `yana-rt` from Yana-AI, so the permission checks are the same in every app
and cannot be skipped by switching clients. Studio never calls a model provider from
its UI layer.

## Download

Get the latest build from the [releases page](https://github.com/Horonomos-laps/Yana-studio/releases/latest)
or from [yana.vutam.link](https://yana.vutam.link). Each release lists its own files,
so check that your platform is there. Releases tagged `app-v*` are the native macOS
app, and its updater reads them.

> [!NOTE]
> The macOS build is ad-hoc signed and **not notarized**, so Gatekeeper warns on first
> launch. Yana-AI's [macOS install guide](https://github.com/Horonomos-laps/Yana-AI/blob/main/docs/MACOS_INSTALL.md)
> shows the two official ways to open it. Verify downloads against `SHA256SUMS` when
> a release provides it.

## The apps

| Directory | App | What it is |
| --- | --- | --- |
| [`yana-app/`](yana-app) | **Yana** for macOS | Native SwiftUI app. Its updater reads this repository's `app-v*` releases. |
| [`yana-studio/`](yana-studio) | **Yana Studio** | Electron workspace for a real project. Windows and Linux builds come from `.github/workflows/yana-studio-desktop.yml`, the native macOS part from `.github/workflows/native-macos.yml`. |
| [`yana-ide/`](yana-ide) | **Yana IDE** | Yana overrides on top of Code-OSS (VS Code). It holds no upstream code. |

### What Yana Studio gives you

| Area | What you get |
| --- | --- |
| **Files and editor** | Open a real folder, search filenames, edit with CodeMirror. Files up to 8 MiB are editable; larger ones open as read-only 256 KiB windows. Saves detect outside changes before overwriting. |
| **Terminals** | Real PTY sessions in tabs, or a grid of up to 12. |
| **Git** | Read-only status, worktrees and diffs. Stage and commit are deliberately not AI tools. |
| **Chat** | Streamed through `yana-rt`, saved conversations, stop button, approval prompts, token usage. |
| **Models** | Every `yana-rt` provider plus a custom OpenAI-compatible endpoint, and a local manager for Ollama, LM Studio, llama.cpp, 9Router and similar. API keys reach Rust over stdin and sit encrypted in the OS keystore, never in workspace files. |
| **Tasks** | Backed by the real `yana-rt task` store. Marking a task done requires evidence, and `blocked` is computed by the runtime. |
| **Design canvas** | Native canvas with components, phone and desktop screens, layers, undo and redo, and guarded AI proposals. |
| **Governance telemetry** | What was allowed, what was blocked, and why. |

Studio is a new app, not a reskin of the older Yana Desktop. It was built on a real
workspace first, with no fake numbers or dead buttons. Per-screen status is in
[`yana-studio/SCREEN-STATUS.md`](yana-studio/SCREEN-STATUS.md).

## Build from source

Studio needs Node 24 or newer and a C++ toolchain for `node-pty` (Xcode command-line
tools on macOS; compiler, make and Python on Linux; Visual Studio C++ and the Windows
SDK on Windows). It also needs a `yana-rt` binary built from Yana-AI.

```bash
git clone https://github.com/Horonomos-laps/Yana-AI.git
cargo build --release --manifest-path Yana-AI/Cargo.toml    # produces yana-rt

cd Yana-studio/yana-studio
npm ci
npm run rebuild
npm run stage:runtime -- /absolute/path/to/Yana-AI/target/release/yana-rt
npm start
npm start -- --project /path/to/project    # open a project directly
```

`stage:runtime` checks that the binary answers a JSON error for empty input, copies it
for the right OS and architecture, and records its SHA-256 in a manifest. That is a
minimal protocol check, not an end-to-end test. Build the runtime from a current
Yana-AI checkout: an old binary does not speak the newer protocol.

## Status

- **Source:** the three apps were moved here from Yana-AI. The macOS app release `app-v1.0.0` is published here. Nothing else has been released from this repository yet, and the two build workflows are new.
- **Partial:** Studio does not yet match every screen of the earlier desktop app. Not built yet: device registry, agent sessions screen, mobile pairing, SSH and Docker execution, permission-lease UI, signed auto-update.
- **Known limits:** the `npm run dist:*` scripts in `yana-studio/` still assume the Yana-AI directory layout, so use the workflow to build packages for now. The desktop build fails until the repository secret `YANA_GOOGLE_CLIENT_SECRET` is set in the repository settings.

## Legacy: Yana Terminal prototype

The root of this repository still holds an earlier terminal prototype (`src/`,
`Cargo.toml`, `DESIGN.md`, `UI_ENGINES.md`, `reference/`). It is a Ratatui UI with mock
data, kept to validate the interaction model. A copy lives in Yana-AI as
`tools/yana-terminal/`. Run it with `cargo run`.

## More

[Yana-AI](https://github.com/Horonomos-laps/Yana-AI) · [yana-web](https://github.com/Horonomos-laps/yana-web) · [yana.vutam.link](https://yana.vutam.link)

Original concept, product direction, architecture and interaction design by **Vũ Văn Tâm**.
AI tools may assist with implementation, testing, documentation and review; accepted
changes stay under maintainer control. Licensed under [Apache 2.0](LICENSE).
