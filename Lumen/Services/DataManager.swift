import Foundation
import SwiftData

@MainActor enum DataManager {
  static func archive(context: ModelContext) throws -> LumenArchive {
    let cycles = try context.fetch(FetchDescriptor<CycleRecord>()).map {
      CyclePayload(
        id: $0.id, startDate: $0.startDate, periodDuration: $0.periodDuration, endDate: $0.endDate)
    }
    let entries = try context.fetch(FetchDescriptor<DailyEntry>()).map {
      EntryPayload(
        id: $0.id, date: $0.date, flow: $0.flowRaw, symptoms: $0.symptomsRaw, mood: $0.mood,
        energy: $0.energy, basalTemperature: $0.basalTemperature, mucus: $0.mucusRaw,
        sexualActivity: $0.sexualActivity, protectionUsed: $0.protectionUsed,
        pillStatus: $0.pillStatusRaw, pillTakenAt: $0.pillTakenAt, note: $0.note)
    }
    let regimen = try context.fetch(FetchDescriptor<PillRegimen>()).first.map {
      PillPayload(
        name: $0.name, activePills: $0.activePills, placeboPills: $0.placeboPills,
        packStart: $0.packStart, reminderHour: $0.reminderHour, reminderMinute: $0.reminderMinute,
        reminderEnabled: $0.reminderEnabled)
    }
    return LumenArchive(cycles: cycles, entries: entries, regimen: regimen)
  }

  static func exportJSON(context: ModelContext) throws -> URL {
    let archive = try archive(context: context)
    let url = FileManager.default.temporaryDirectory.appending(
      path: "Lumen-Export-\(Date.now.formatted(.iso8601.year().month().day())).json"
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(archive)
    try data.write(to: url, options: .atomic)
    return url
  }

  static func importJSON(from url: URL, context: ModelContext) throws {
    let granted = url.startAccessingSecurityScopedResource()
    defer { if granted { url.stopAccessingSecurityScopedResource() } }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let archive = try decoder.decode(LumenArchive.self, from: Data(contentsOf: url))
    try purge(context: context)
    for cycle in archive.cycles {
      let value = CycleRecord(
        startDate: cycle.startDate,
        periodDuration: cycle.periodDuration,
        endDate: cycle.endDate)
      value.id = cycle.id
      context.insert(value)
    }
    for entry in archive.entries {
      let value = DailyEntry(date: entry.date)
      value.id = entry.id
      value.flowRaw = entry.flow
      value.symptomsRaw = entry.symptoms
      value.mood = entry.mood
      value.energy = entry.energy
      value.basalTemperature = entry.basalTemperature
      value.mucusRaw = entry.mucus
      value.sexualActivity = entry.sexualActivity
      value.protectionUsed = entry.protectionUsed
      value.pillStatusRaw = entry.pillStatus
      value.pillTakenAt = entry.pillTakenAt
      value.note = entry.note
      context.insert(value)
    }
    if let p = archive.regimen {
      let value = PillRegimen(packStart: p.packStart)
      value.name = p.name
      value.activePills = p.activePills
      value.placeboPills = p.placeboPills
      value.reminderHour = p.reminderHour
      value.reminderMinute = p.reminderMinute
      value.reminderEnabled = p.reminderEnabled
      context.insert(value)
    }
    try context.save()
  }

  static func purge(context: ModelContext) throws {
    try context.delete(model: DailyEntry.self)
    try context.delete(model: CycleRecord.self)
    try context.delete(model: PillRegimen.self)
    try context.save()
  }
}
