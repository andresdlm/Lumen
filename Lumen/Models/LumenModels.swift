import Foundation
import SwiftData
import SwiftUI

enum CyclePhase: String, Codable, CaseIterable, Identifiable {
  case menstrual, follicular, fertile, ovulation, luteal
  var id: String { rawValue }
  var title: String {
    self == .menstrual ? "Period" : self == .fertile ? "Fertile window" : rawValue.capitalized
  }
  var symbol: String {
    switch self {
    case .menstrual: "drop.fill"
    case .follicular: "moon.stars.fill"
    case .fertile: "leaf.fill"
    case .ovulation: "sparkles"
    case .luteal: "sun.haze.fill"
    }
  }
}

enum PrimaryGoal: String, Codable, CaseIterable, Identifiable {
  case tracking, conceiving, symptoms, birthControl
  var id: String { rawValue }
  var title: String {
    switch self {
    case .tracking: "Track my cycle"
    case .conceiving: "Trying to conceive"
    case .symptoms: "Symptoms & patterns"
    case .birthControl: "Birth control"
    }
  }
  var detail: String {
    switch self {
    case .tracking: "Predictions, phases, and period reminders"
    case .conceiving: "Fertile window, BBT, and mucus"
    case .symptoms: "Mood, pain, and energy over time"
    case .birthControl: "Daily pill reminders and streaks"
    }
  }
  var symbol: String {
    switch self {
    case .tracking: "circle.dotted"
    case .conceiving: "leaf.fill"
    case .symptoms: "chart.dots.scatter"
    case .birthControl: "pills.fill"
    }
  }
}

enum FlowLevel: Int, Codable, CaseIterable, Identifiable {
  case none, spotting, light, medium, heavy
  var id: Int { rawValue }
  var title: String { rawValue == 0 ? "None" : String(describing: self).capitalized }
}

enum Symptom: String, Codable, CaseIterable, Identifiable {
  case cramps, headache, bloating, acne, tenderBreasts, fatigue, backPain, nausea, insomnia,
    dizziness, cravings
  var id: String { rawValue }
  var title: String {
    rawValue.replacingOccurrences(of: "Breasts", with: " breasts").replacingOccurrences(
      of: "Pain", with: " pain"
    ).capitalized
  }
}

enum CervicalMucus: String, Codable, CaseIterable, Identifiable {
  case dry, sticky, creamy, watery, eggWhite
  var id: String { rawValue }
  var title: String { self == .eggWhite ? "Egg white" : rawValue.capitalized }
}

enum PillStatus: String, Codable { case pending, taken, late, skipped, placebo }

@Model final class CycleRecord {
  var id: UUID = UUID()
  var startDate: Date = Date.now
  var periodDuration: Int = 5
  var endDate: Date?

  init(startDate: Date, periodDuration: Int = 5, endDate: Date? = nil) {
    self.startDate = Calendar.current.startOfDay(for: startDate)
    self.periodDuration = periodDuration
    self.endDate = endDate
  }

  var length: Int? {
    endDate.flatMap { Calendar.current.dateComponents([.day], from: startDate, to: $0).day }
  }
}

@Model final class DailyEntry {
  var id: UUID = UUID()
  var date: Date = Date.now
  var flowRaw: Int = FlowLevel.none.rawValue
  var symptomsRaw: [String] = []
  var mood: Int = 0
  var energy: Int = 3
  var basalTemperature: Double?
  var mucusRaw: String?
  var sexualActivity: Bool = false
  var protectionUsed: Bool = false
  var pillStatusRaw: String = PillStatus.pending.rawValue
  var pillTakenAt: Date?
  var note: String = ""

  init(date: Date) { self.date = Calendar.current.startOfDay(for: date) }
  var flow: FlowLevel {
    get { FlowLevel(rawValue: flowRaw) ?? .none }
    set { flowRaw = newValue.rawValue }
  }
  var symptoms: Set<Symptom> {
    get { Set(symptomsRaw.compactMap(Symptom.init)) }
    set { symptomsRaw = newValue.map(\.rawValue) }
  }
  var mucus: CervicalMucus? {
    get { mucusRaw.flatMap(CervicalMucus.init) }
    set { mucusRaw = newValue?.rawValue }
  }
  var pillStatus: PillStatus {
    get { PillStatus(rawValue: pillStatusRaw) ?? .pending }
    set { pillStatusRaw = newValue.rawValue }
  }
}

@Model final class PillRegimen {
  var id: UUID = UUID()
  var name: String = "Combined pill"
  var activePills: Int = 21
  var placeboPills: Int = 7
  var packStart: Date = Date.now
  var reminderHour: Int = 21
  var reminderMinute: Int = 0
  var reminderEnabled: Bool = false

  init(packStart: Date = .now) { self.packStart = Calendar.current.startOfDay(for: packStart) }
  var packLength: Int { max(1, activePills + placeboPills) }
  func offset(on date: Date = .now) -> Int {
    max(
      0,
      Calendar.current.dateComponents(
        [.day], from: packStart, to: Calendar.current.startOfDay(for: date)
      ).day ?? 0) % packLength
  }
  func day(on date: Date = .now) -> Int { offset(on: date) + 1 }
  func isPlacebo(on date: Date = .now) -> Bool { offset(on: date) >= activePills }
}

struct LumenArchive: Codable {
  var version = 1
  var exportedAt = Date.now
  var cycles: [CyclePayload]
  var entries: [EntryPayload]
  var regimen: PillPayload?
}

struct CyclePayload: Codable {
  var id: UUID
  var startDate: Date
  var periodDuration: Int
  var endDate: Date?
}
struct EntryPayload: Codable {
  var id: UUID
  var date: Date
  var flow: Int
  var symptoms: [String]
  var mood: Int
  var energy: Int
  var basalTemperature: Double?
  var mucus: String?
  var sexualActivity: Bool
  var protectionUsed: Bool
  var pillStatus: String
  var pillTakenAt: Date?
  var note: String
}
struct PillPayload: Codable {
  var name: String
  var activePills: Int
  var placeboPills: Int
  var packStart: Date
  var reminderHour: Int
  var reminderMinute: Int
  var reminderEnabled: Bool
}
