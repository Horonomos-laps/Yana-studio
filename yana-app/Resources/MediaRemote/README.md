# MediaRemote Adapter (third-party, bundled unchanged)

Files in this folder are built from https://github.com/ungive/mediaremote-adapter (BSD 3-Clause, see LICENSE),
commit 65714990277cb4d0415ebaf7fff6be3229362b28, with `cmake .. && cmake --build .`:

- `mediaremote-adapter.pl`: the script, copied unchanged.
- `MediaRemoteAdapter.framework`, `MediaRemoteAdapterTestClient`: built from that source, ad-hoc signed.

Yana runs `/usr/bin/perl mediaremote-adapter.pl MediaRemoteAdapter.framework stream` to read what any app is playing
(YouTube in a browser, Spotify, ...), because macOS 15.4 and later no longer lets ordinary apps read it directly.
The framework is bundled and never linked against. Yana checks it with the `test` command first and falls back to
AppleScript when it does not work.

Copyright (c) 2025, Jonas van den Berg and contributors.
