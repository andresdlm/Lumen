import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(\.modelContext) private var context
  @Environment(HealthKitManager.self) private var health
  @Environment(CloudBackupManager.self) private var cloud
  @AppStorage("appLockEnabled") private var appLock = false
  @AppStorage("hideInAppSwitcher") private var hideSwitcher = true
  @AppStorage("healthSyncEnabled") private var healthSync = false
  @AppStorage("healthReadEnabled") private var healthRead = false
  @AppStorage("healthWriteEnabled") private var healthWrite = false
  @AppStorage("iCloudBackupEnabled") private var cloudEnabled = false
  @AppStorage("averageCycleLength") private var cycleLength = 28
  @AppStorage("averagePeriodDuration") private var periodDuration = 5
  @Query private var regimens: [PillRegimen]
  @State private var exportItem: ExportItem?
  @State private var importing = false
  @State private var showPurge = false
  @State private var message: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Cycle") {
          Stepper("Average cycle: \(cycleLength) days", value: $cycleLength, in: 21...45)
          Stepper("Average period: \(periodDuration) days", value: $periodDuration, in: 2...10)
        }
        Section("Privacy") {
          Toggle(isOn: $appLock) {
            SettingsIconLabel(
              symbol: "faceid",
              tint: LumenTheme.lavender,
              title: "App lock",
              detail: "Require Face ID, Touch ID, or passcode.")
          }
          Toggle(isOn: $hideSwitcher) {
            SettingsIconLabel(
              symbol: "rectangle.on.rectangle.slash",
              tint: LumenTheme.lavender,
              title: "Hide in App Switcher",
              detail: "Cover cycle information in app previews.")
          }
        }
        Section("Health & sync") {
          Toggle(isOn: $healthSync) {
            SettingsIconLabel(
              symbol: "heart.text.square.fill",
              tint: LumenTheme.blush,
              title: "Sync with Apple Health",
              detail: "Read and write cycle data, BBT, and activity.")
          }
          .onChange(of: healthSync) { _, enabled in updateHealthSync(enabled) }
          Toggle(isOn: $cloudEnabled) {
            SettingsIconLabel(
              symbol: "icloud.fill",
              tint: LumenTheme.mint,
              title: "iCloud backup",
              detail: cloudDetail)
          }
          .onChange(of: cloudEnabled) { _, enabled in
            if enabled { Task { await cloud.upload(context: context) } }
          }
          if cloudEnabled {
            Button {
              Task { await cloud.upload(context: context) }
            } label: {
              Label("Back up now", systemImage: "arrow.clockwise.icloud")
            }
            Button {
              Task { await cloud.restore(context: context) }
            } label: {
              Label("Restore iCloud backup", systemImage: "arrow.down.icloud")
            }
            if cloud.isWorking { ProgressView() }
          }
        }
        Section("Pill reminder") {
          if let regimen = regimens.first {
            PillSettings(regimen: regimen)
          } else {
            Button("Set up pill tracking") {
              context.insert(PillRegimen())
              try? context.save()
            }
          }
        }
        Section("Your data") {
          Button {
            exportJSON()
          } label: {
            SettingsActionLabel(title: "Export as JSON", symbol: "square.and.arrow.up")
          }
          Button {
            importing = true
          } label: {
            SettingsActionLabel(title: "Import backup file", symbol: "square.and.arrow.down")
          }
          Button(role: .destructive) {
            showPurge = true
          } label: {
            Label("Erase all data", systemImage: "trash")
          }
        }
        Section {
          VStack(alignment: .leading, spacing: 6) {
            Label("Open source & privacy first", systemImage: "checkmark.seal.fill").font(.headline)
            Text(
              "Lumen 1.0 · No account or Lumen server. Health and iCloud access remain optional, and backups stay in your private iCloud database."
            ).font(.footnote).foregroundStyle(.secondary)
          }
        }
      }.scrollContentBackground(.hidden).background(AmbientBackground(phase: .fertile))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
          if healthRead || healthWrite { healthSync = true }
        }
        .sheet(item: $exportItem) { item in ShareSheet(url: item.url) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
          do {
            try DataManager.importJSON(from: try result.get(), context: context)
            message = "Import complete."
          } catch { message = error.localizedDescription }
        }
        .alert("Erase all data?", isPresented: $showPurge) {
          Button("Erase", role: .destructive) {
            do {
              try DataManager.purge(context: context)
              UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            } catch { message = error.localizedDescription }
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text(
            "This permanently removes every local cycle and entry. Export first if you need a backup."
          )
        }
        .alert(
          "Lumen",
          isPresented: Binding(
            get: { message != nil || health.lastError != nil || cloud.errorMessage != nil },
            set: {
              if !$0 {
                message = nil
                health.lastError = nil
                cloud.errorMessage = nil
              }
            })
        ) {
          Button("OK") {}
        } message: {
          Text(message ?? health.lastError ?? cloud.errorMessage ?? "")
        }
    }
  }
  private var cloudDetail: String {
    if let date = cloud.lastBackup {
      return "Private database · updated \(date.formatted(.relative(presentation: .named)))"
    }
    return "Encrypted in transit and stored in your private database."
  }

  private func updateHealthSync(_ enabled: Bool) {
    healthRead = enabled
    healthWrite = enabled
    guard enabled else { return }
    Task {
      let authorized = await health.requestAuthorization()
      healthSync = authorized
      healthRead = authorized
      healthWrite = authorized
      if authorized { await health.importRecent(into: context) }
    }
  }

  private func exportJSON() {
    do {
      exportItem = ExportItem(url: try DataManager.exportJSON(context: context))
    } catch {
      message = error.localizedDescription
    }
  }
}

private struct SettingsIconLabel: View {
  let symbol: String
  let tint: Color
  let title: String
  let detail: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 32, height: 32)
        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

private struct SettingsActionLabel: View {
  let title: String
  let symbol: String

  var body: some View {
    HStack {
      Label(title, systemImage: symbol)
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
  }
}

private struct PillSettings: View {
  @Bindable var regimen: PillRegimen
  var body: some View {
    Toggle("Daily reminder", isOn: $regimen.reminderEnabled).onChange(of: regimen.reminderEnabled) {
      _, enabled in
      Task {
        if enabled {
          try? await NotificationManager.shared.schedulePillReminder(
            hour: regimen.reminderHour, minute: regimen.reminderMinute)
        } else {
          NotificationManager.shared.cancelPillReminder()
        }
      }
    }
    DatePicker(
      "Reminder time",
      selection: Binding(
        get: {
          Calendar.current.date(
            from: DateComponents(hour: regimen.reminderHour, minute: regimen.reminderMinute))
            ?? .now
        },
        set: {
          let values = Calendar.current.dateComponents([.hour, .minute], from: $0)
          regimen.reminderHour = values.hour ?? 21
          regimen.reminderMinute = values.minute ?? 0
          if regimen.reminderEnabled {
            Task {
              try? await NotificationManager.shared.schedulePillReminder(
                hour: regimen.reminderHour, minute: regimen.reminderMinute)
            }
          }
        }), displayedComponents: .hourAndMinute)
    DatePicker("Pack started", selection: $regimen.packStart, displayedComponents: .date)
  }
}

private struct ShareSheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct ExportItem: Identifiable {
  let url: URL
  var id: URL { url }
}
