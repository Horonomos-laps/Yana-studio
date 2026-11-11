# Yana Studio and Yana app

Source for the Yana desktop apps. They were split out of the main repository,
[Yana-AI](https://github.com/Horonomos-laps/Yana-AI), which keeps the Rust runtime
(`yana-rt`), the `core/` rules and hooks, and the PyPI and crates.io packages.

## What is here

| Directory | What it is |
|---|---|
| `yana-app/` | The native macOS app (SwiftUI). Its updater reads the releases of this repository whose tag starts with `app-v`. |
| `yana-studio/` | Yana Studio, an Electron app. See its own README. Windows and Linux builds: `.github/workflows/yana-studio-desktop.yml`. The native macOS part (`yana-studio/native-macos`): `.github/workflows/native-macos.yml`. |
| `yana-ide/` | Yana overrides on top of Code-OSS (VS Code). It holds no upstream code. See its own README. |
| `src/`, `Cargo.toml`, `docs/`, `reference/` | The earlier terminal prototype, described at the bottom. A copy now lives in Yana-AI as `tools/yana-terminal/`. |

## Status

- The three app directories are copies from Yana-AI (`tools/yana-app`, `tools/yana-studio`, `tools/yana-ide`). Nothing has been built from this repository yet, and the two workflows have not run here.
- Studio builds need the Rust runtime, so the workflow checks out Yana-AI beside this repository to build `yana-rt`.
- No release tagged `app-v*` exists here yet, so the app updater finds no update. Studio downloads (`studio-v*` tags) are still on the Yana-AI releases page until the first tag is made here.
- The `npm run dist:*` scripts in `yana-studio/` still assume the Yana-AI directory layout. Use the workflow to build for now.
- The website and the web server live in [yana-web](https://github.com/Horonomos-laps/yana-web).

## Legacy: Yana Terminal AI Workspace

A terminal-native, local-first AI workspace for developers.

This repository is currently an **UI/UX incubator** for the next Yana terminal experience. The current MVP uses mock data so the interaction model can be validated before connecting it back to `yana-rt` and the existing local-AI stack in `Yana-AI/tools/yana-web`.

### Current MVP

- Transcript-first interface
- Adaptive activity and plan sidebar
- Smart Scope overlay
- Plan overlay
- Keyboard-first composer
- Local runtime/model status
- High-contrast terminal theme
- SPDX copyright headers

### Run

```bash
cargo run
```

### Controls

| Key | Action |
|---|---|
| `Ctrl+S` | Open Smart Scope |
| `Ctrl+P` | Open Plan Tracker |
| `Tab` | Toggle sidebar |
| `Enter` | Submit mock prompt / close overlay |
| `Esc` | Close overlay / quit |
| `Ctrl+C` | Quit |

### Architecture boundary

The MVP intentionally implements only the terminal presentation layer and mock state:

```text
src/app/      interaction state and keyboard events
src/domain/   UI-facing data models
src/ui/       adaptive Ratatui rendering
reference/    legacy code for study only
```

Provider adapters, model downloads, runtime management, safety guards, and session storage will not be duplicated here. They will be connected later through a small bridge to the existing Yana systems.

### Project direction

- Local-first and privacy-first
- Scope before deep repository scanning
- Evidence for code claims
- Review before applying changes
- Capability-based model support
- Terminal-native rather than a GUI drawn with characters

### Authorship

Original concept, product direction, architecture, and interaction design by **Vũ Văn Tâm**.

AI tools may assist with implementation, testing, documentation, and review. Accepted changes remain under maintainer control.

Licensed under Apache-2.0.

### UI engine surface

The terminal now exposes fourteen deliberately UI-facing engines:

1. Chat
2. Composer
3. Render
4. Layout
5. Workflow
6. Provider
7. Session
8. Storage
9. Search
10. Command
11. Context View
12. Attachment
13. Notification
14. Theme

These engines coordinate terminal state and mock interaction only. They do not replace Yana Core, execute shell commands, mutate the workspace, or persist credentials.

### MVP commands

```text
/help
/engines
/clear
/new
/provider [name]
/search <text>
/attach <workspace-relative-path>
/theme
/render
/save
```
