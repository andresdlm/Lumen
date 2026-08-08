import SwiftData
import SwiftUI

struct DailyLogView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var context
  @Environment(HealthKitManager.self) private var health
  @Query private var entries: [DailyEntry]
  let date: Date
  @State private var flow = FlowLevel.none
  @State private var symptoms = Set<Symptom>()
  @State private var mood = 0
  @State private var energy = 3
  @State private var temperature: Double?
  @State private var mucus: CervicalMucus?
  @State private var sexualActivity = false
  @State private var protectionUsed = false
  @State private var note = ""
  @AppStorage("healthWriteEnabled") private var healthWriteEnabled = false

  var body: some View {
    NavigationStack {
      ZStack {
        AmbientBackground(phase: .menstrual)
        ScrollView {
          VStack(spacing: 14) {
            section("Menstrual flow") {
              HStack(spacing: 7) {
                ForEach(FlowLevel.allCases) { item in
                  choice(item.title, selected: flow == item, tint: LumenTheme.blush) { flow = item }
                }
              }
            }
            section("Physical symptoms") {
              FlowLayout(items: Symptom.allCases, selection: $symptoms)
            }
            section("Mood & energy") {
              VStack(alignment: .leading) {
                Text("Mood: \(moodName)").font(.subheadline.bold())
                Slider(
                  value: Binding(get: { Double(mood) }, set: { mood = Int($0) }), in: -2...2,
                  step: 1
                ).tint(LumenTheme.lavender)
                Text("Energy: \(energy)/5").font(.subheadline.bold())
                Slider(
                  value: Binding(get: { Double(energy) }, set: { energy = Int($0) }), in: 1...5,
                  step: 1
                ).tint(LumenTheme.sand)
              }
            }
            section("Basal temperature") {
              HStack {
                TextField(
                  "36.50", value: $temperature, format: .number.precision(.fractionLength(2))
                ).keyboardType(.decimalPad).font(.title2.bold())
                Text("°C").foregroundStyle(.secondary)
                Spacer()
                Menu(mucus?.title ?? "Mucus") {
                  Button("Not logged") { mucus = nil }
                  ForEach(CervicalMucus.allCases) { value in Button(value.title) { mucus = value } }
                }
              }
            }
            section("Intimacy") {
              VStack {
                Toggle("Sexual activity", isOn: $sexualActivity)
                if sexualActivity { Toggle("Protection used", isOn: $protectionUsed) }
              }
            }
            section("Private note") {
              TextField("Anything else you noticed…", text: $note, axis: .vertical).lineLimit(3...6)
            }
          }.padding(20)
        }
      }.navigationTitle(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .navigationBarTitleDisplayMode(.inline).toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }.fontWeight(.semibold)
          }
        }.onAppear(perform: load)
    }
  }
  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {
        Text(title).font(.headline)
        content()
      }
    }
  }
  private func choice(_ title: String, selected: Bool, tint: Color, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Text(title).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.7).frame(
        maxWidth: .infinity
      ).padding(.vertical, 12).foregroundStyle(selected ? .white : .secondary).background(
        selected ? tint : .primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
    }.buttonStyle(.plain)
  }
  private var moodName: String { ["Very low", "Low", "Neutral", "Good", "Great"][mood + 2] }
  private func load() {
    guard let entry = existing else { return }
    flow = entry.flow
    symptoms = entry.symptoms
    mood = entry.mood
    energy = entry.energy
    temperature = entry.basalTemperature
    mucus = entry.mucus
    sexualActivity = entry.sexualActivity
    protectionUsed = entry.protectionUsed
    note = entry.note
  }
  private var existing: DailyEntry? {
    entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
  }
  private func save() {
    let entry = existing ?? DailyEntry(date: date)
    if existing == nil { context.insert(entry) }
    entry.flow = flow
    entry.symptoms = symptoms
    entry.mood = mood
    entry.energy = energy
    entry.basalTemperature = temperature
    entry.mucus = mucus
    entry.sexualActivity = sexualActivity
    entry.protectionUsed = protectionUsed
    entry.note = note
    try? context.save()
    if healthWriteEnabled { Task { await health.write(entry) } }
    dismiss()
  }
}

private struct FlowLayout: View {
  let items: [Symptom]
  @Binding var selection: Set<Symptom>
  let columns = [GridItem(.adaptive(minimum: 105), spacing: 8)]
  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
      ForEach(items) { item in
        Button(item.title) {
          if selection.contains(item) { selection.remove(item) } else { selection.insert(item) }
        }.font(.subheadline.weight(selection.contains(item) ? .semibold : .regular)).padding(
          .horizontal, 13
        ).padding(.vertical, 9).frame(maxWidth: .infinity).background(
          selection.contains(item) ? LumenTheme.lavender.opacity(0.25) : .primary.opacity(0.05),
          in: Capsule()
        ).buttonStyle(.plain)
      }
    }
  }
}
