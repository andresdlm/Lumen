# Repository Guidelines

## Project Structure & Module Organization

Lumen is a SwiftUI iOS application managed by `Lumen.xcodeproj`. Application code lives in `Lumen/`: `LumenApp.swift` defines the app entry point, while `ContentView.swift` contains the initial screen. Images, colors, and app icons belong in `Lumen/Assets.xcassets`; add new asset sets there rather than embedding binary resources beside Swift files. Project build settings and file membership are maintained in `Lumen.xcodeproj`.

There is currently no test target. When adding tests, create `LumenTests/` for unit tests and, if needed, `LumenUITests/` for UI tests, matching the source organization where practical.

## Build, Test, and Development Commands

- `open Lumen.xcodeproj` opens the project in Xcode for local development and SwiftUI previews.
- `xcodebuild -project Lumen.xcodeproj -scheme Lumen -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` performs a command-line debug build without signing.
- `xcodebuild -project Lumen.xcodeproj -scheme Lumen clean` removes Xcode build products.
- `xcodebuild test -project Lumen.xcodeproj -scheme Lumen -destination 'platform=iOS Simulator,name=<device>'` runs tests after a test target is added; replace `<device>` with an installed simulator.

## Coding Style & Naming Conventions

Use standard Swift and SwiftUI conventions: four-space indentation, one primary type per file, and trailing closures for view builders. Name types in `UpperCamelCase` and properties/functions in `lowerCamelCase`. SwiftUI view types should describe their role and end in `View` when useful, such as `SettingsView`. Keep `body` declarative; extract repeated or complex sections into focused subviews. Use Xcode's **Editor > Structure > Re-Indent** before committing. No repository-wide formatter or linter is currently configured.

## Testing Guidelines

Use XCTest for unit and UI tests. Name test files after the subject (`ContentViewTests.swift`) and test methods by behavior, for example `testGreetingAppearsOnLaunch()`. Cover new logic and regressions; use SwiftUI previews for visual iteration, not as a replacement for automated tests.

## Commit & Pull Request Guidelines

The history currently contains only `Initial Commit`, so no established convention exists. Use short, imperative commit subjects such as `Add settings screen`, keeping each commit focused. Pull requests should explain the change and verification performed, link relevant issues, and include screenshots or recordings for visible UI changes. Note any new assets, permissions, or build-setting changes explicitly.
