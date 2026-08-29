# Changelog

All notable changes to Lumo are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Translation window: a compact destination menu on the result row. Change it
  for this request only — Settings defaults stay put.

### Changed

- Translate routing no longer assumes a native language. Any input goes to the
  default target; input already in that target flips to the flip-back language.
  A third language (e.g. Japanese when the pair is Chinese/English) now goes to
  the target instead of being sent "home".

## [0.2.2] - 2026-08-28

### Added

- Settings: Thinking Off / On (default Off) for OpenAI and OpenAI-compatible
  providers. Off disables chain-of-thought on hybrid models such as Qwen 3/3.5
  via Ollama, so translations no longer stall on a reasoning trace.

## [0.2.1] - 2026-06-15

### Fixed

- Translation history could disappear: the database was stored at a shared
  system location that any other app could overwrite. History now lives in
  Lumo's own folder, and any history still present from the old location is
  carried over automatically on first launch after updating.

## [0.2.0] - 2026-06-15

### Added

- Keyboard-first translation window: ⌘1 / ⌘2 / ⌘3 switch between Translate,
  Polish, and Summary, and ⌘R regenerates the current result. Each mode segment
  shows its shortcut hint.
- ⌘Y opens the translation history and ⌘P pins/unpins the window, matching the
  toolbar buttons; both shortcuts are shown in the buttons' tooltips.
- Markdown tables in results now render as a bordered grid instead of raw
  `| --- |` pipe-and-dash text. All other output stays as plain, selectable,
  copyable text.
- The translation window now grows to fit the result — up to 85% of the
  screen — and only scrolls past that, so short answers no longer leave empty
  space and long ones stay readable. The window animates as the result streams
  in and settles to an exact fit once it finishes.

### Changed

- The translation window's action button is now labelled "Run" (it runs the
  selected mode) instead of always "Translate", and the "Summarize" mode is now
  labelled "Summary".
- Translation, polish, and summarize now preserve the source structure
  (line breaks, lists, headings) in their results.

### Fixed

- Text-to-speech no longer reads markdown markers and table pipes aloud
  (`*`, `#`, `|`, and similar symbols are stripped before speaking).

## [0.1.9] - 2026-06-13

### Added

- Screen-area OCR from the menu bar: drag-select text on screen, recognize it
  locally with macOS Vision, and send the result into Lumo. Includes Screen
  Recording permission guidance and a configurable global shortcut in Settings.
- Local OCR sample evaluation harness for tuning recognition quality against
  real screenshot fixtures.
- The menu-bar menu now shows your assigned global shortcuts for "New
  Translation…" and "OCR Screen Text…" next to each item, updating live as you
  re-record them in Settings.

## [0.1.8] - 2026-06-12

### Added

- "Apple (On-Device)" provider powered by Apple's Foundation Models framework:
  runs the system language model entirely on-device with no API key, network,
  or cost. Requires an Apple Intelligence–capable Mac on macOS 26+; Settings
  shows a live readiness status and a clear message when the model is
  unavailable.

### Changed

- Refreshed the app icon and replaced the menu-bar glyph with a custom Lumo
  icon (previously the generic `character.bubble` system symbol).

## [0.1.7] - 2026-06-02

### Added

- Press ⇥ in an empty translation window to paste the clipboard and translate
  it in one keystroke. The placeholder advertises the shortcut only when the
  clipboard actually holds text.

## [0.1.6] - 2026-06-02

### Added

- Global keyboard shortcut for "New Translation…": assign a system-wide hotkey
  in Settings to open an empty translation window from any app. No shortcut is
  set by default — pick your own under Settings → Shortcut.

## [0.1.5] - 2026-05-31

### Added

- Editable input mode in the translation window: the captured selection now
  appears in an editable field, so you can tweak or correct it before running
  translate, polish, or summarize — and read either the input or the result
  aloud.

### Fixed

- Translation popup no longer clips its toolbar buttons (retranslate, copy,
  close) past the right edge: the window's minimum width now fits the full
  header, so those actions stay visible and clickable.

## [0.1.4] - 2026-05-30

### Added

- Localized interface in English and Simplified Chinese, covering both the
  native app UI and the PopClip extension action labels.

## [0.1.3] - 2026-05-30

### Added

- In-app auto-update via [Sparkle](https://sparkle-project.org/): Lumo checks
  for new versions in the background and can update itself from the menu bar —
  no need to clear the quarantine flag again after the first launch.

## [0.1.2] - 2026-05-30

### Added

- About panel.
- Per-provider base URL isolation, so each provider keeps its own endpoint.

### Changed

- Redesigned the translation popup as a Liquid Glass slab.

### Fixed

- Settings window layout and behavior.

## [0.1.1] - 2026-05-25

### Added

- Native macOS app icon.

## [0.1.0] - 2026-05-25

### Added

- Initial release. Lumo translates, polishes, and summarizes selected text on
  macOS via an LLM, triggered from PopClip:
  - **PopClip extension** (`Lumo.popclipext/`) — a thin trigger that hands the
    selected text to the app through a `lumo://` URL scheme.
  - **Native menu-bar app** (`mac-app/`) — talks to the LLM provider, streams
    the result into a window, keeps a history, and can read it aloud.

[Unreleased]: https://github.com/iuhoay/lumo/compare/v0.1.9...HEAD
[0.1.9]: https://github.com/iuhoay/lumo/compare/v0.1.8...v0.1.9
[0.1.8]: https://github.com/iuhoay/lumo/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/iuhoay/lumo/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/iuhoay/lumo/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/iuhoay/lumo/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/iuhoay/lumo/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/iuhoay/lumo/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/iuhoay/lumo/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/iuhoay/lumo/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/iuhoay/lumo/releases/tag/v0.1.0
