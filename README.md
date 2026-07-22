# Spellbook

Spellbook is a native macOS library for discovering, reading, and safely managing skills installed across Claude Code, Cursor, and Codex.

Product and implementation context:

- [Product](PRODUCT.md)
- [Design system](DESIGN.md)
- [Locked brief](docs/SPELLBOOK-BRIEF.md)
- [Build plan](docs/BUILD-PLAN.md)
- [Implementation verification](docs/IMPLEMENTATION-VERIFICATION.md)
- [Release checklist](docs/RELEASE-CHECKLIST.md)

## Development

Generate the Xcode project:

```sh
xcodegen generate
```

Build the app without a signing identity:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Spellbook.xcodeproj \
  -scheme Spellbook \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run package and macOS UI tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test \
  --package-path Packages/SpellbookKit \
  -Xswiftc -warnings-as-errors

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Spellbook.xcodeproj \
  -scheme Spellbook \
  -destination 'platform=macOS' \
  test
```

## Direct distribution

The release scripts intentionally require an Apple Developer team and local
notary keychain profile; credentials are never stored in this repository. See
[the release checklist](docs/RELEASE-CHECKLIST.md) before producing a public
artifact.
