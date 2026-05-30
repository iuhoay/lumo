---
name: release
description: Cut a Lumo release — bump the version in mac-app/project.yml (both places), roll CHANGELOG.md [Unreleased] into a dated section, commit, tag vX.Y.Z, and push to trigger the GitHub Actions release pipeline. Use when asked to "release", "cut a release", or "ship vX.Y.Z".
disable-model-invocation: true
---

# Cut a Lumo release

Pushing a `vX.Y.Z` tag triggers `.github/workflows/release.yml`, which builds,
EdDSA-signs, generates `appcast.xml`, and publishes the GitHub Release. This
skill does the local prep that must land **before** the tag.

`$ARGUMENTS` is the target version `X.Y.Z` (no leading `v`). If absent, infer the
next version from `CHANGELOG.md` `[Unreleased]` contents (Added → minor bump,
only Fixed/Changed → patch bump) and confirm it with the user before proceeding.

## Steps

1. **Preflight.** Confirm a clean working tree (`git status --porcelain` empty)
   and that you are on `main` (`git branch --show-current`). If not, stop and
   tell the user. Verify the tag `vX.Y.Z` does not already exist
   (`git tag -l vX.Y.Z`).

2. **Bump the version in `mac-app/project.yml` — both places:**
   - `MARKETING_VERSION: "X.Y.Z"` (under `settings.base`).
   - `CFBundleShortVersionString: "X.Y.Z"` (under `targets.Lumo.info.properties`).

   Do not touch `CURRENT_PROJECT_VERSION` / `CFBundleVersion` — CI sets the build
   number from the git commit count.

3. **Update `CHANGELOG.md`** (Keep a Changelog format). Rename the existing
   `## [Unreleased]` heading to `## [X.Y.Z] - YYYY-MM-DD` (today's date), keeping
   its `### Added/Changed/Fixed` content. Then insert a fresh empty
   `## [Unreleased]` section above it. The dated heading must read exactly
   `[X.Y.Z]` — `scripts/release_notes.py` matches on it. If `[Unreleased]` is
   empty, ask the user what this release contains before continuing.

4. **Regenerate the project** so the committed state is consistent:
   `cd mac-app && xcodegen generate`. (A PostToolUse hook may already have run
   this after the project.yml edit — running it again is harmless.)

5. **Commit:** `git add -A && git commit -m "chore: release vX.Y.Z"`.

6. **Tag and push:**
   ```sh
   git tag vX.Y.Z
   git push origin main
   git push origin vX.Y.Z
   ```

7. **Report.** Tell the user the tag is pushed and link the Actions run:
   `https://github.com/iuhoay/lumo/actions`. The release artifacts (`Lumo.zip`,
   `appcast.xml`) and notes are produced by CI, not locally.

Do all of steps 5–6 only after the user has seen the diff, unless they told you
to proceed without confirmation.
