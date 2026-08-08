import SwiftData
import SwiftUI

struct CycleCalendarView: View {
  @Query(sort: \CycleRecord.startDate, order: .reverse) private var cycles: [CycleRecord]
  @Query private var entries: [DailyEntry]
  @AppStorage("averageCycleLength") private var cycleLength = 28
  @AppStorage("averagePeriodDuration") private var periodDuration = 5
  @State private var month =
    Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now))
    ?? .now
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

  var body: some View {
    NavigationStack {
      ZStack {
        AmbientBackground(phase: .follicular)
        ScrollView {
          VStack(spacing: 18) {
            HStack(alignment: .bottom) {
              VStack(alignment: .leading, spacing: 2) {
                Text(month.formatted(.dateTime.month(.wide))).font(.largeTitle.bold())
                Text(monthSubtitle).font(.subheadline).foregroundStyle(.secondary)
              }
              Spacer()
              HStack(spacing: 16) {
                Button {
                  shift(-1)
                } label: {
                  Image(systemName: "chevron.left")
                }
                Button {
                  shift(1)
                } label: {
                  Image(systemName: "chevron.right")
                }
              }
              .font(.headline)
              .foregroundStyle(LumenTheme.accent)
              .padding(.bottom, 6)
            }
            .padding(.horizontal, 2)
            GlassCard(padding: 14) {
              VStack(spacing: 8) {
                LazyVGrid(columns: columns, spacing: 6) {
                  ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(.secondary)
                      .padding(.bottom, 4)
                  }
                  ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                      dayCell(date)
                    } else {
                      Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                  }
                }
              }
            }
            legend
          }
          .padding(.horizontal, 20)
          .padding(.top, 8)
          .padding(.bottom, 30)
        }
      }
    }
  }

  private var predictor: CyclePredictor {
    CyclePredictor(
      averageCycleLength: CyclePredictor.learnedLength(from: cycles, fallback: cycleLength),
      averagePeriodDuration: periodDuration)
  }
  private var anchor: Date { cycles.first?.startDate ?? .now }
  private var monthSubtitle: String {
    let year = month.formatted(.dateTime.year())
    let logged = entries.filter {
      Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month)
    }.count
    return "\(year) · \(logged) \(logged == 1 ? "day" : "days") logged"
  }
  private var weekdaySymbols: [String] {
    let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
    let offset = max(0, Calendar.current.firstWeekday - 1)
    return Array(symbols[offset...] + symbols[..<offset])
  }
  private var days: [Date?] {
    guard let range = Calendar.current.range(of: .day, in: .month, for: month),
      let first = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: month))
    else { return [] }
    let weekday = Calendar.current.component(.weekday, from: first)
    let leading = (weekday - Calendar.current.firstWeekday + 7) % 7
    return Array(repeating: nil, count: leading)
      + range.compactMap { Calendar.current.date(byAdding: .day, value: $0 - 1, to: first) }.map(
        Optional.some)
  }
  private func dayCell(_ date: Date) -> some View {
    let start = predictor.periodStart(containing: date, anchor: anchor)
    let phase = predictor.phase(on: date, lastStart: start)
    let entry = entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    let isPredictedPeriod = date > Date.now && phase == .menstrual
    let fill = dayFill(phase: phase, entry: entry)
    return ZStack {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(fill)
      VStack(spacing: 3) {
        Text("\(Calendar.current.component(.day, from: date))").font(
          .subheadline.weight(Calendar.current.isDateInToday(date) ? .bold : .regular))
        Circle().fill(entry == nil ? .clear : .primary.opacity(0.55)).frame(width: 4, height: 4)
      }
    }
    .frame(maxWidth: .infinity)
    .aspectRatio(1, contentMode: .fit)
    .overlay {
      if Calendar.current.isDateInToday(date) {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(LumenTheme.accent, lineWidth: 2)
      } else if isPredictedPeriod {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(LumenTheme.blush, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(dayAccessibilityLabel(date: date, phase: phase, hasEntry: entry != nil))
  }
  private func dayAccessibilityLabel(date: Date, phase: CyclePhase, hasEntry: Bool) -> String {
    let entryDescription = hasEntry ? ", has entry" : ""
    return "\(date.formatted(date: .complete, time: .omitted)), \(phase.title)\(entryDescription)"
  }
  private func dayFill(phase: CyclePhase, entry: DailyEntry?) -> Color {
    if let entry, entry.flow != .none {
      return LumenTheme.blush.opacity(0.22 + Double(entry.flowRaw) * 0.14)
    }
    return phase.tint.opacity(phase == .menstrual ? 0.28 : 0.16)
  }
  private var legend: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 7) {
        CalendarLegendItem(title: "Period", tint: LumenTheme.blush)
        CalendarLegendItem(title: "Fertile", tint: LumenTheme.mint)
        CalendarLegendItem(title: "Luteal", tint: LumenTheme.sand)
      }
      HStack(spacing: 7) {
        CalendarLegendItem(title: "Predicted", tint: LumenTheme.blush, isPredicted: true)
        CalendarLegendItem(title: "Has entry", tint: .secondary, isEntry: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  private func shift(_ value: Int) {
    withAnimation {
      month = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month
    }
  }
}

private struct CalendarLegendItem: View {
  let title: String
  let tint: Color
  var isPredicted = false
  var isEntry = false

  var body: some View {
    HStack(spacing: 6) {
      Group {
        if isEntry {
          Circle().fill(tint).frame(width: 4, height: 4)
        } else if isPredicted {
          Circle().stroke(tint, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            .frame(width: 9, height: 9)
        } else {
          Circle().fill(tint).frame(width: 8, height: 8)
        }
      }
      Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay { Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 0.5) }
  }
}
