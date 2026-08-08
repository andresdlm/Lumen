import Foundation

struct CyclePredictor {
  var averageCycleLength: Int
  var averagePeriodDuration: Int
  private var safeLength: Int { max(21, averageCycleLength) }
  var ovulationDay: Int { max(8, safeLength - 14) }
  var fertileRange: ClosedRange<Int> {
    max(1, ovulationDay - 5)...min(safeLength, ovulationDay + 1)
  }

  static func learnedLength(from cycles: [CycleRecord], fallback: Int) -> Int {
    let lengths = cycles.compactMap(\.length).suffix(6)
    guard !lengths.isEmpty else { return fallback }
    return Int((Double(lengths.reduce(0, +)) / Double(lengths.count)).rounded())
  }

  func cycleDay(on date: Date, lastStart: Date) -> Int {
    let elapsed =
      Calendar.current.dateComponents(
        [.day], from: Calendar.current.startOfDay(for: lastStart),
        to: Calendar.current.startOfDay(for: date)
      ).day ?? 0
    return max(1, elapsed >= 0 ? elapsed % safeLength + 1 : 1)
  }

  func phase(on date: Date, lastStart: Date) -> CyclePhase {
    let day = cycleDay(on: date, lastStart: lastStart)
    if day <= averagePeriodDuration { return .menstrual }
    if day == ovulationDay { return .ovulation }
    if fertileRange.contains(day) { return .fertile }
    return day < fertileRange.lowerBound ? .follicular : .luteal
  }

  func nextPeriod(after start: Date) -> Date {
    Calendar.current.date(byAdding: .day, value: safeLength, to: start) ?? start
  }
  func periodStart(containing date: Date, anchor: Date) -> Date {
    var start = anchor
    while start > date {
      start = Calendar.current.date(byAdding: .day, value: -safeLength, to: start) ?? start
    }
    while let next = Calendar.current.date(byAdding: .day, value: safeLength, to: start),
      next <= date
    { start = next }
    return start
  }
}
