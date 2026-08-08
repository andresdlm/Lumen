# Lumen

Lumen is an open-source, privacy-first cycle tracker for iOS. It stores cycle history locally, performs predictions on device, and does not require an account or use a Lumen-operated server.

## Features

- Private onboarding and on-device cycle forecasts
- Menstrual flow, symptoms, mood, BBT, intimacy, and pill logging
- Phase-aware dashboard and monthly calendar
- Apple Health read/write synchronization
- Optional private iCloud backup through CloudKit
- Local pill reminders and biometric app lock
- Complete JSON backup export and import

## Requirements

- iOS 18 or later
- A current Xcode release with the iOS 18 SDK or later
- An Apple Developer team for device signing and capabilities

## Getting Started

1. Clone the repository.
2. Open `Lumen.xcodeproj` in Xcode.
3. Select the **Lumen** target and choose your development team.
4. Enable HealthKit and iCloud/CloudKit capabilities for your bundle identifier.
5. Create or select the `iCloud.com.andresdlm.Lumen` CloudKit container, or update the entitlement to your own container.
6. Build and run on an iOS 18 simulator or device.

For a command-line build:

```sh
xcodebuild -project Lumen.xcodeproj -scheme Lumen \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Privacy

The SwiftData store is explicitly local-only. HealthKit and CloudKit are opt-in. Cloud backups are written to the user's private CloudKit database. Exported JSON files contain sensitive health information; users are responsible for storing and sharing them securely.

## Medical Disclaimer

Lumen provides estimates for informational purposes only. It is not medical advice, a diagnostic tool, or a method of contraception. Predictions may be inaccurate. Seek qualified medical advice for health concerns and emergencies.

## Contributing

Read [AGENTS.md](AGENTS.md) for repository structure, coding conventions, verification commands, and pull-request expectations.

## License

Lumen is available under the [MIT License](LICENSE). The software is provided “as is,” without warranty; its authors and contributors are not liable for claims, damages, health decisions, data loss, or other consequences arising from its use.
