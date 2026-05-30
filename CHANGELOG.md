# Changelog

All notable changes to Lumo are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/iuhoay/lumo/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/iuhoay/lumo/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/iuhoay/lumo/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/iuhoay/lumo/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/iuhoay/lumo/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/iuhoay/lumo/releases/tag/v0.1.0
