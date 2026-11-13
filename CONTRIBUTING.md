# Contributing to Yana-studio · Đóng góp cho Yana-studio

> **[Tiếng Việt bên dưới / Vietnamese below](#tiếng-việt)**

This repository holds the desktop apps of the Yana ecosystem. The runtime (`yana-rt`), rules, hooks, agents and skills live in
[Yana-AI](https://github.com/Horonomos-laps/Yana-AI); read its [CONTRIBUTING.md](https://github.com/Horonomos-laps/Yana-AI/blob/main/CONTRIBUTING.md) for anything about those.
Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md). Security problems go to [SECURITY.md](SECURITY.md), never to a public issue.

## What is in this repository

| Path | What it is | Checked by |
|---|---|---|
| `yana-studio/` | Yana Studio: Electron app (TypeScript, Vite, node-pty) | `js-tests.yml`, `yana-studio-desktop.yml` |
| `yana-app/` | Native macOS app (SwiftUI, Swift package) | `yana-app-macos.yml` |
| `yana-ide/` | Overlay on Code-OSS: patches and extensions, not VS Code source | `js-tests.yml` (job `yana-ide`) |
| `src/`, `Cargo.toml` | Rust crate `yana-terminal` (terminal workspace) | `rust.yml` |

`yana-studio/native-macos/` is a separate Swift app checked by `native-macos.yml`.

## Principles

1. **Real data only.** No placeholder numbers or buttons that do nothing. A partial screen is recorded as partial in `yana-studio/SCREEN-STATUS.md`; screenshots are not runtime proof.
2. **The renderer never calls a provider.** Chat goes through `yana-rt`. API keys reach Rust over stdin (never argv), are stored per provider with Electron `safeStorage`, and are never returned to the renderer or written to workspace JSON, localStorage or logs.
3. **No silent data loss.** State is written to a temp file, fsynced, then renamed; a corrupt file keeps a recovery copy.
4. **The apps do not decide what the AI may do.** The runtime does. Some tests compare Studio with files in Yana-AI (the model catalog, the capability registry, `COMMANDS.md`, hook and lock files). If you change those in Yana-AI, change Studio in a matching PR and link them.

## Build and run the Studio app

Needs Node 24+, a C++ toolchain for `node-pty`, and a `yana-rt` built from a current Yana-AI checkout.

```bash
git clone https://github.com/Horonomos-laps/Yana-AI.git
cargo build --release --manifest-path Yana-AI/Cargo.toml     # produces yana-rt
git clone https://github.com/Horonomos-laps/Yana-studio.git
cd Yana-studio/yana-studio
npm ci
npm run rebuild
npm run stage:runtime -- /absolute/path/to/Yana-AI/target/release/yana-rt
npm start
```

`stage:runtime` only sends an empty input and checks for a JSON error: a minimal protocol probe, not an end-to-end test. Do not commit the `runtime/` output.

## Before you open a PR

Run the checks for the part you changed and paste the output in the PR.

```bash
# yana-studio/ (this is what CI runs, with Yana-AI checked out next to this repo)
cd yana-studio
npm ci --ignore-scripts
export YANA_ROOT_DIR=/path/to/Yana-AI        # the tests compare against this checkout
node --test --test-timeout=120000 test/*.test.cjs
npm run build                                # tsc --noEmit && vite build
npm run format:check                         # prettier

# the Rust crate at the repo root
cargo fmt --all -- --check
cargo test --all-targets
```

Not run by CI, so run them yourself when relevant: `npm run test:electron`, `npm run test:ui`, and the Swift builds on macOS (`swift build` and `swift test` in `yana-app/` or `yana-studio/native-macos/`).
For `yana-ide/` follow `yana-ide/README.md` and `yana-ide/tests/README.md`.

## What we accept

| Type | Welcome? | Notes |
|---|---|---|
| Bug fix | ✅ | Include a failing test in `test/` where one can exist |
| A screen or feature from `SCREEN-STATUS.md` | ✅ | Real data; update that file in the same PR |
| Fake or sample data to fill a screen | ❌ | Show an honest empty or not-implemented state |
| Calling a provider from the renderer | ❌ | Goes through `yana-rt` |
| Credentials in any file, log or fixture | ❌ | Rejected at PR stage |
| Packaging, signing or release workflow changes | Discuss first | Open an Issue titled `design-proposal: ...` |

Discuss first when a change touches 5+ files across modules, changes the `yana-rt` protocol the apps expect, or changes a persisted state format.

## Code and UI

- No hardcoded hex colors in frontend code; use the theme tokens. Keep to `DESIGN.md`.
- A file over 300 lines or a function over 50 lines needs a reason in the PR.
- Do not commit build output (`/target`, `node_modules/`, `runtime/`, `release/`); check `git status` first.
- OAuth tests use local fixtures. Real consent, provider registration and signed native-store tests are listed in `yana-studio/OAUTH-AUDIT.md`; do not describe them as done.

## Commits and PRs

```
type(scope): short description        types: feat, fix, chore, docs, refactor, test, perf
fix(studio): keep the terminal shell alive when Settings is hidden
```

One topic per PR, from the latest `main`. Several people or agents at once: one branch per git worktree. Do not push tags; the maintainer cuts releases.

```
□ Output of the checks above pasted (not "should pass")
□ SCREEN-STATUS.md updated if a screen changed
□ No secrets, no keys in argv, nothing sensitive in logs or fixtures
□ No hardcoded hex colors
□ If a Yana-AI file the tests compare against changed: linked PR in Yana-AI
```

## License

Contributions are licensed under Apache-2.0, the license of this repository. Keep upstream attribution (`yana-studio/ACKNOWLEDGEMENTS.md`).

---

## Tiếng Việt

Repo này chứa các ứng dụng desktop của hệ sinh thái Yana. Runtime `yana-rt`, rule, hook, agent và skill nằm ở
[Yana-AI](https://github.com/Horonomos-laps/Yana-AI). Mọi người tham gia tuân theo [Quy tắc ứng xử](CODE_OF_CONDUCT.md); lỗ hổng bảo mật gửi theo [SECURITY.md](SECURITY.md), không mở issue công khai.

**Thành phần:** `yana-studio/` (app Electron), `yana-app/` (app macOS SwiftUI), `yana-ide/` (lớp sửa đè Code-OSS), `src/` cùng `Cargo.toml` (crate Rust `yana-terminal`).

**Nguyên tắc:** chỉ dùng dữ liệu thật; renderer không gọi provider (đi qua `yana-rt`); API key vào Rust qua stdin, lưu bằng `safeStorage`, không trả lại renderer hay ghi vào log; ghi file tạm rồi đổi tên để không mất dữ liệu; một số test so sánh với file trong Yana-AI nên sửa phía Yana-AI thì phải có PR tương ứng ở đây.

**Chạy thử:** cần Node 24+, bộ công cụ C++ cho `node-pty` và `yana-rt` build từ Yana-AI mới (các lệnh ở phần tiếng Anh). Không commit `runtime/`.

**Trước khi mở PR:** chạy kiểm tra cho phần bạn sửa và dán output (lệnh ở phần tiếng Anh). CI chạy `node --test` cho `yana-studio/test`, `cargo fmt` và `cargo test`; `npm run test:electron`, `npm run test:ui` và build Swift thì CI không chạy, hãy tự chạy khi liên quan.

**Chấp nhận:** sửa lỗi kèm test; màn hình trong `SCREEN-STATUS.md` với dữ liệu thật. **Không chấp nhận:** dữ liệu mẫu lấp màn hình, gọi provider từ renderer, credential trong file/log/fixture. Thay đổi đóng gói, ký, release hoặc chạm 5+ file xuyên module thì thảo luận trước.

**Quy tắc code:** không hardcode màu hex; file quá 300 dòng hoặc hàm quá 50 dòng cần nêu lý do; không commit output build. Commit theo `type(scope): mô tả ngắn`, mỗi PR một chủ đề, không push tag.

Đóng góp được cấp phép Apache-2.0, giấy phép của repo này.
