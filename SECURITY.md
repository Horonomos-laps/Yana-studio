# Security Policy — Yana-studio · Chính sách bảo mật

> **[Tiếng Việt bên dưới / Vietnamese below](#tiếng-việt)**

## Supported versions

Only the latest published release of Yana Studio is supported
([Releases](https://github.com/Horonomos-laps/Yana-studio/releases/latest)). Builds you make from `main` are supported at `main`.
This is a solo-maintained project, so there is no long-term-support line.

## Reporting a vulnerability

**Do not open a public GitHub Issue for a security problem.**

- **GitHub Security Advisories**: Security tab of this repository, then *Report a vulnerability*.
- **Email**: the address in the [Yana-AI security policy](https://github.com/Horonomos-laps/Yana-AI/blob/main/SECURITY.md), with `Yana-studio SECURITY` in the subject.

Include the app and version, your OS, the steps to reproduce, and what an attacker gains.
We aim to acknowledge a report within 48 hours and to patch critical issues within 7 days, the same targets as the Yana-AI policy.

## Scope

In scope, because the apps hold or handle them:

| Type | Example |
|---|---|
| Provider key exposure | A path that returns a stored key to the renderer, or writes it to workspace JSON, localStorage, argv or a log |
| Renderer to host escape | Content in a chat, file or terminal that reaches Node or the OS outside the declared IPC |
| Runtime bypass | A way for the app to make a model request that skips `yana-rt` and its governance |
| Terminal and file handling | Writing outside the opened project, or overwriting a file changed outside the editor |
| OAuth and account | Token leakage, a wrong redirect, or a connection that persists after it is removed |
| Release integrity | A published installer that contains secrets or local state, or a staged `yana-rt` that is not the one that was checked |

Out of scope: flaws in the model providers or in tools you run in the terminal, problems in `yana-rt` itself (report to
[Yana-AI](https://github.com/Horonomos-laps/Yana-AI/blob/main/SECURITY.md)), and your own machine being already compromised.

## Known limits

- OAuth has been tested against local fixtures only; real consent, provider registrations and signed native-store tests are open (`yana-studio/OAUTH-AUDIT.md`).
- On Linux without a keyring, `safeStorage` falls back to `basic_text`: the app then keeps a key in memory for the session only.
- No prebuilt macOS Studio build exists for every release; check the release's file list.

## Disclosure

We follow coordinated disclosure: we credit reporters unless they ask not to, avoid public detail until a fix or mitigation exists, and do not pursue good-faith research that follows this policy.

---

## Tiếng Việt

Chỉ bản phát hành mới nhất của Yana Studio được hỗ trợ. **Không mở issue công khai cho lỗ hổng bảo mật.** Báo riêng qua GitHub Security Advisories của repo này, hoặc email ghi trong [chính sách bảo mật của Yana-AI](https://github.com/Horonomos-laps/Yana-AI/blob/main/SECURITY.md) với tiêu đề có `Yana-studio SECURITY`. Chúng tôi cố gắng xác nhận trong 48 giờ và vá lỗi nghiêm trọng trong 7 ngày.

**Trong phạm vi:** lộ API key, thoát từ renderer ra máy, vượt qua `yana-rt`, ghi file ngoài project, rò token OAuth, gói phát hành chứa secret. **Ngoài phạm vi:** lỗi ở provider hoặc công cụ chạy trong terminal, lỗi của `yana-rt` (báo ở Yana-AI), máy đã bị xâm nhập.

**Giới hạn đã biết:** OAuth mới thử với fixture cục bộ; trên Linux không có keyring, key chỉ giữ trong RAM của phiên; không phải bản phát hành nào cũng có bản dựng macOS.
