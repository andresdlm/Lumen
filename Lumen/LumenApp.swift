import SwiftData
import SwiftUI

@main
struct LumenApp: App {
  private let container: ModelContainer
  @State private var healthKit = HealthKitManager()
  @State private var appLock = AppLockManager()
  @State private var cloudBackup = CloudBackupManager()

  init() {
    do {
      let configuration = ModelConfiguration(cloudKitDatabase: .none)
      container = try ModelContainer(
        for: CycleRecord.self,
        DailyEntry.self,
        PillRegimen.self,
        configurations: configuration)
    } catch {
      fatalError("Unable to open Lumen’s private data store: \(error.localizedDescription)")
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(healthKit).environment(appLock).environment(cloudBackup)
    }
    .modelContainer(container)
  }
}
