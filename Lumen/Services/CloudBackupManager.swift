import CloudKit
import Foundation
import SwiftData

@Observable final class CloudBackupManager {
  private let container = CKContainer.default()
  private var database: CKDatabase { container.privateCloudDatabase }
  var isWorking = false
  var lastBackup: Date?
  var errorMessage: String?

  @MainActor func upload(context: ModelContext) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await requireAvailableAccount()
      let archive = try DataManager.archive(context: context)
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let recordID = CKRecord.ID(recordName: "lumen-private-backup")
      let record =
        (try? await database.record(for: recordID))
        ?? CKRecord(recordType: "LumenBackup", recordID: recordID)
      record["payload"] = try encoder.encode(archive) as CKRecordValue
      record["updatedAt"] = Date.now as CKRecordValue
      _ = try await database.save(record)
      lastBackup = .now
    } catch { errorMessage = error.localizedDescription }
  }

  @MainActor func restore(context: ModelContext) async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await requireAvailableAccount()
      let record = try await database.record(for: CKRecord.ID(recordName: "lumen-private-backup"))
      guard let data = record["payload"] as? Data else { return }
      let url = FileManager.default.temporaryDirectory.appending(path: "Lumen-iCloud-Restore.json")
      try data.write(to: url, options: .atomic)
      try DataManager.importJSON(from: url, context: context)
      lastBackup = record["updatedAt"] as? Date
    } catch { errorMessage = error.localizedDescription }
  }

  private func requireAvailableAccount() async throws {
    let status = try await container.accountStatus()
    guard status == .available else { throw CloudBackupError.accountUnavailable }
  }
}

private enum CloudBackupError: LocalizedError {
  case accountUnavailable

  var errorDescription: String? {
    "Sign in to iCloud in Settings before enabling Lumen’s private backup."
  }
}
