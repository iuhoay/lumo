# Security Policy

## Supported versions

Security fixes are handled on the latest released version of Lumo.

## Reporting a vulnerability

Please do not open a public issue for security-sensitive reports. Email the
maintainer at the contact address listed on the GitHub profile instead.

Include:

- Lumo version
- macOS version
- Steps to reproduce
- Any relevant logs or screenshots

Do not include API keys or other secrets in the report.

## API key storage

Lumo is currently distributed as an unsigned app. Because unsigned macOS apps do
not have a stable code identity for Keychain access prompts, Lumo stores provider
API keys in its own `UserDefaults` instead of Keychain.

This means provider keys are stored locally in plaintext for the current macOS
user account. The key is not stored in the PopClip extension, and Lumo does not
send it anywhere except to the configured provider endpoint when making model
requests.

Use a provider key scoped for Lumo, rotate it if needed, and avoid using a key
with broader account privileges than necessary.
