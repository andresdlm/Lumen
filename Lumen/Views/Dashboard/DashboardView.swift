import SwiftData
import SwiftUI

struct DashboardView: View {
  @Query(sort: \CycleRecord.startDate, order: .reverse) private var cycles: [CycleRecord]
  @Query(sort: \DailyEntry.date, order: .reverse) private var entries: [DailyEntry]
  @Query private var regimens: [PillRegimen]
  @AppStorage("averageCycleLength") private var configuredLength = 28
  @AppStorage("averagePeriodDuration") private var periodDuration = 5

  @Binding var showingLog: Bool

  private var lastStart: Date { cycles.first?.startDate ?? .now }
  private var predictor: CyclePredictor {
    CyclePredictor(
      averageCycleLength: CyclePredictor.learnedLength(
        from: cycles,
        fallback: configuredLength),
      averagePeriodDuration: periodDuration)
  }
  private var phase: CyclePhase { predictor.phase(on: .now, lastStart: lastStart) }

  var body: some View {
    ZStack {
      AmbientBackground(phase: phase)
      ScrollView {
        VStack(spacing: 14) {
          header
          if let regimen = regimens.first {
            DashboardPillTracker(regimen: regimen, entries: entries)
          }
          HStack(alignment: .top, spacing: 12) {
            BasalTemperatureCard(entries: entries)
            PatternInsightCard(entries: entries, predictor: predictor, lastStart: lastStart)
          }
          Text("Predictions are estimates, not medical advice or contraception.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
      .scrollIndicators(.hidden)
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
          .font(.caption.weight(.semibold))
          .kerning(0.9)
          .foregroundStyle(.secondary)
        Text("Today").font(.title.bold())
      }
      Spacer()
      HStack(spacing: 8) {
        DashboardGlassButton(symbol: "plus") {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          showingLog = true
        }
        .accessibilityLabel("Log today")
      }
    }
    .padding(.top, 8)
  }

}

private struct DashboardGlassButton: View {
  let symbol: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.body.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(width: 44, height: 44)
        .background(.ultraThinMaterial, in: Circle())
        .overlay { Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
    }
    .buttonStyle(.plain)
  }
}

private struct DashboardPillTracker: View {
  @Environment(\.modelContext) private var context
  let regimen: PillRegimen
  let entries: [DailyEntry]

  private var todayEntry: DailyEntry? {
    entries.first { Calendar.current.isDateInToday($0.date) }
  }
  private var isTaken: Bool { todayEntry?.pillStatus == .taken }
  private var todayOffset: Int { regimen.offset() }
  private var streak: Int {
    var count = 0
    var cursor = Calendar.current.startOfDay(for: .now)
    while let entry = entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: cursor) }
    ),
      entry.pillStatus == .taken
    {
      count += 1
      cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
    }
    return count
  }

  var body: some View {
    GlassCard(padding: 18) {
      VStack(spacing: 16) {
        HStack(spacing: 14) {
          PillGlyph()
            .frame(width: 48, height: 48)
            .background(
              LumenTheme.coral.opacity(0.2),
              in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          VStack(alignment: .leading, spacing: 2) {
            Text("\(regimen.name) · \(regimen.activePills)/\(regimen.packLength) pack")
              .font(.headline)
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
          statusButton
        }
        packStrip
        HStack {
          Text("\(streak)-day streak")
          Spacer()
          Text(placeboCopy)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
      }
    }
  }

  private var subtitle: String {
    if isTaken, let time = todayEntry?.pillTakenAt {
      return
        "Logged \(time.formatted(date: .omitted, time: .shortened)) · day \(regimen.day()) of pack"
    }
    if regimen.isPlacebo() {
      return "Placebo day \(regimen.day() - regimen.activePills) of \(regimen.placeboPills)"
    }
    let time =
      DateComponents(calendar: .current, hour: regimen.reminderHour, minute: regimen.reminderMinute)
      .date ?? .now
    return
      "Daily at \(time.formatted(date: .omitted, time: .shortened)) · day \(regimen.day()) of pack"
  }

  private var placeboCopy: String {
    let days = regimen.activePills - regimen.day()
    return days > 0
      ? "\(regimen.placeboPills) placebo days in \(days)d" : "Withdrawal bleed expected"
  }

  @ViewBuilder private var statusButton: some View {
    if isTaken {
      Label("Taken", systemImage: "checkmark")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(LumenTheme.mint, in: Capsule())
    } else {
      Button(regimen.isPlacebo() ? "Log" : "Take now") { takePill() }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(LumenTheme.accent, in: Capsule())
        .buttonStyle(.plain)
    }
  }

  private var packStrip: some View {
    HStack(spacing: 4) {
      ForEach(0..<regimen.packLength, id: \.self) { offset in
        RoundedRectangle(cornerRadius: 7, style: .continuous)
          .fill(packColor(offset))
          .frame(maxWidth: .infinity)
          .frame(height: 26)
          .overlay {
            if offset == todayOffset {
              RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
            }
          }
          .accessibilityLabel("Pack day \(offset + 1)")
      }
    }
  }

  private func packColor(_ offset: Int) -> Color {
    if offset > todayOffset {
      return offset >= regimen.activePills ? .primary.opacity(0.04) : .primary.opacity(0.07)
    }
    if offset == todayOffset { return isTaken ? LumenTheme.mint : LumenTheme.coral.opacity(0.5) }
    let date = Calendar.current.date(byAdding: .day, value: offset - todayOffset, to: .now) ?? .now
    let taken = entries.contains {
      Calendar.current.isDate($0.date, inSameDayAs: date) && $0.pillStatus == .taken
    }
    return taken ? LumenTheme.coral : LumenTheme.blush.opacity(0.3)
  }

  private func takePill() {
    let entry = todayEntry ?? DailyEntry(date: .now)
    if todayEntry == nil { context.insert(entry) }
    entry.pillStatus = .taken
    entry.pillTakenAt = .now
    try? context.save()
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }
}

private struct PillGlyph: View {
  var body: some View {
    ZStack {
      Capsule()
        .fill(
          LinearGradient(
            colors: [LumenTheme.coral, LumenTheme.coral.opacity(0.45)],
            startPoint: .top,
            endPoint: .bottom)
        )
        .frame(width: 22, height: 22)
      Rectangle().fill(.white.opacity(0.55)).frame(width: 22, height: 1)
    }
    .rotationEffect(.degrees(-35))
  }
}

private struct BasalTemperatureCard: View {
  let entries: [DailyEntry]

  private var temperatures: [Double] {
    Array(entries.sorted { $0.date < $1.date }.compactMap(\.basalTemperature).suffix(14))
  }

  var body: some View {
    GlassCard(padding: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("BASAL TEMP")
          .font(.caption2.weight(.semibold))
          .kerning(0.8)
          .foregroundStyle(.secondary)
        Text(temperatures.last.map { String(format: "%.2f° C", $0) } ?? "—")
          .font(.system(size: 25, weight: .bold, design: .rounded))
          .minimumScaleFactor(0.75)
          .lineLimit(1)
        HStack(alignment: .bottom, spacing: 3) {
          ForEach(Array(temperatures.enumerated()), id: \.offset) { index, value in
            RoundedRectangle(cornerRadius: 3)
              .fill(index >= temperatures.count - 3 ? LumenTheme.mint : Color.primary.opacity(0.13))
              .frame(maxWidth: .infinity)
              .frame(height: max(6, min(38, (value - 36) * 100)))
          }
        }
        .frame(height: 38, alignment: .bottom)
        .padding(.top, 8)
        Text(temperatureDetail).font(.footnote).foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var temperatureDetail: String {
    guard temperatures.count > 1, let latest = temperatures.last else {
      return "Log BBT to see your shift"
    }
    let baseline = temperatures.dropLast().reduce(0, +) / Double(temperatures.count - 1)
    return String(format: "%+.2f° vs recent mean", latest - baseline)
  }
}

private struct PatternInsightCard: View {
  let entries: [DailyEntry]
  let predictor: CyclePredictor
  let lastStart: Date

  private var topSymptom: Symptom? {
    var counts: [Symptom: Int] = [:]
    for entry in entries { for symptom in entry.symptoms { counts[symptom, default: 0] += 1 } }
    return counts.max(by: { $0.value < $1.value })?.key
  }
  private var matchingEntries: Int {
    guard let topSymptom else { return 0 }
    return entries.filter { $0.symptoms.contains(topSymptom) }.count
  }

  var body: some View {
    GlassCard(padding: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Text("PATTERN")
          .font(.caption2.weight(.semibold))
          .kerning(0.8)
          .foregroundStyle(.secondary)
        Text(headline).font(.callout.weight(.semibold))
        Text(detail).font(.footnote).foregroundStyle(.secondary)
        HStack(spacing: 5) {
          ForEach(0..<6, id: \.self) { index in
            Capsule()
              .fill(
                index < min(5, matchingEntries) ? LumenTheme.blush : Color.primary.opacity(0.12)
              )
              .frame(height: 6)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var headline: String {
    guard let topSymptom else { return "Patterns appear as you log" }
    let days = entries.filter { $0.symptoms.contains(topSymptom) }.map {
      predictor.cycleDay(on: $0.date, lastStart: lastStart)
    }
    let averageDay = days.isEmpty ? 0 : days.reduce(0, +) / days.count
    return "\(topSymptom.title) clusters near day \(averageDay)"
  }

  private var detail: String {
    guard topSymptom != nil else { return "Computed privately from your daily entries." }
    return "Seen on \(matchingEntries) logged days. Computed on device."
  }
}
