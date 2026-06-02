import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// System-wide hotkey that opens an empty translation window for manual input
    /// (the "New Translation…" menu action). Ships with NO default: global
    /// hotkeys are first-come-first-served and popular combos (⌥⌘N, ⌘Space…) are
    /// routinely already taken by other launchers, so the user records their own
    /// in Settings. KeyboardShortcuts persists the choice in UserDefaults; until
    /// one is set, nothing is registered and the action is menu-only.
    static let newTranslation = Self("newTranslation")
}
