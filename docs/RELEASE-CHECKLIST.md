# Spellbook Release Checklist

Use this checklist for a Developer ID direct-download release. Do not use a
development build as the release artifact.

## Inputs

- Final AppIcon asset catalog approved.
- Apple Developer team identifier.
- Installed `Developer ID Application` certificate.
- A `notarytool` keychain profile created outside this repository.
- Marketing and build versions confirmed in `project.yml`.

## Build and verify

1. Run `swift test --package-path Packages/SpellbookKit -Xswiftc -warnings-as-errors`.
2. Run the full `xcodebuild ... test` command from the README.
3. Run `scripts/archive-release.sh` with `SPELLBOOK_DEVELOPMENT_TEAM` and,
   when needed, `SPELLBOOK_SIGNING_IDENTITY` set in the shell.
4. Launch the archived app on a clean account before notarization.
5. Verify discovery with no agents, one agent, and Claude/Cursor/Codex together.
6. Verify offline reading/editing, denied and restored folder access, one
   external edit conflict, Update All with a modified target, removal restore,
   and crash recovery.
7. Repeat essential smoke checks on macOS 14 and the current supported macOS.

## Notarize and package

1. Run `scripts/notarize-release.sh <keychain-profile>`.
2. Confirm `notarytool` reports Accepted.
3. Confirm `stapler validate` succeeds on the app.
4. Confirm `spctl --assess --type execute` accepts the app.
5. Distribute the final `Spellbook-<version>.zip` emitted after stapling.

## Acknowledgements

- GRDB.swift 7.11.1 — MIT License, copyright Gwendal Roué.
- Swift Markdown 0.8.0 — Apache License 2.0, Apple Inc. and Swift project authors.
- Swift CMark / cmark-gfm — BSD-2-Clause and bundled upstream notices.

The complete upstream license and notice files are available in the resolved
Swift package checkouts and must be included with the public distribution's
acknowledgements.
