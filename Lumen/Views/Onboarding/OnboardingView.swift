import SwiftData
import SwiftUI

struct OnboardingView: View {
  @Environment(\.modelContext) private var context
  @Environment(HealthKitManager.self) private var health
  @State private var step = 0
  @State private var navigationDirection = 1
  @State private var lastPeriod =
    Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
  @State private var periodDuration = 5
  @State private var cycleLength = 28
  @State private var selectedGoals: Set<PrimaryGoal> = [.tracking]
  @State private var wantsAppLock = true
  @State private var wantsHealthKit = false
  @State private var wantsNotifications = true
  var onFinish: () -> Void

  var body: some View {
    ZStack {
      AmbientBackground(phase: .fertile)
      VStack(spacing: 18) {
        if step > 0 {
          HStack(spacing: 7) {
            ForEach(1...4, id: \.self) {
              Capsule().fill($0 <= step ? LumenTheme.accent : .primary.opacity(0.1)).frame(
                height: 4)
            }
          }.padding(.horizontal, 24)
        }
        ZStack {
          currentStep
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(step)
            .transition(
              .asymmetric(
                insertion: .move(edge: navigationDirection > 0 ? .trailing : .leading),
                removal: .move(edge: navigationDirection > 0 ? .leading : .trailing)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        if step > 0 { controls.padding(.horizontal, 22).padding(.bottom, 8) }
      }
    }
  }

  private var welcome: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 28)
      Image(systemName: "lock.fill")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(LumenTheme.accent)
        .frame(width: 76, height: 76)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(.white.opacity(0.48), lineWidth: 0.75)
        }
        .shadow(color: LumenTheme.accent.opacity(0.14), radius: 20, y: 10)
      Text("Your cycle,\non your device.").font(.largeTitle.bold()).padding(.top, 26)
      Text(
        "No account, no email, no cloud we can read. Open source, end to end."
      ).foregroundStyle(.secondary).padding(.top, 12)
      VStack(spacing: 10) {
        WelcomePrivacyRow(
          symbol: "person.crop.circle.badge.xmark",
          tint: LumenTheme.blush,
          title: "Zero accounts",
          detail: "Nothing to sign up for, ever.")
        WelcomePrivacyRow(
          symbol: "iphone.gen3",
          tint: LumenTheme.lavender,
          title: "Local storage only",
          detail: "Your history remains in Lumen’s protected container.")
        WelcomePrivacyRow(
          symbol: "checkmark.seal",
          tint: LumenTheme.mint,
          title: "Open and auditable",
          detail: "Transparent code and on-device predictions.")
      }.padding(.top, 28)
      Spacer(minLength: 20)
      Button("Set up my forecast") { moveForward() }.buttonStyle(PrimaryButtonStyle())
      Text("Takes about 30 seconds")
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }.padding(24)
  }

  private var periodStep: some View {
    scaffold("When did your last period start?", "You can update this at any time.") {
      GlassCard(padding: 10) {
        DatePicker(
          "Last period", selection: $lastPeriod, in: ...Date.now, displayedComponents: .date
        ).datePickerStyle(.graphical).labelsHidden().tint(LumenTheme.accent)
      }
    }
  }
  private var durationStep: some View {
    scaffold(
      "How long, usually?", "Estimates are fine. Lumen re-learns from every cycle you log."
    ) {
      DurationMetricCard {
        VStack(alignment: .leading, spacing: 18) {
          DurationStepperHeader(
            label: "Bleeding days",
            value: periodDuration,
            tint: LumenTheme.accent,
            onMinus: { periodDuration = max(1, periodDuration - 1) },
            onPlus: { periodDuration = min(10, periodDuration + 1) })
          HStack(spacing: 5) {
            ForEach(1...10, id: \.self) { index in
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                  index <= periodDuration ? LumenTheme.blush : Color.primary.opacity(0.08)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 14 + CGFloat(index) * 3)
            }
          }
          .animation(.easeInOut(duration: 0.25), value: periodDuration)
        }
      }
      DurationMetricCard {
        VStack(alignment: .leading, spacing: 18) {
          DurationStepperHeader(
            label: "Cycle length",
            value: cycleLength,
            tint: LumenTheme.lavender,
            onMinus: { cycleLength = max(21, cycleLength - 1) },
            onPlus: { cycleLength = min(35, cycleLength + 1) })
          Slider(
            value: Binding(
              get: { Double(cycleLength) },
              set: { cycleLength = Int($0) }),
            in: 21...35,
            step: 1
          ) {
            Text("Cycle length")
          } minimumValueLabel: {
            Text("21").font(.footnote).foregroundStyle(.tertiary)
          } maximumValueLabel: {
            Text("35").font(.footnote).foregroundStyle(.tertiary)
          }
          .tint(LumenTheme.lavender)
        }
      }
    }
  }
  private var goalStep: some View {
    scaffold(
      "What are you here for?",
      "Choose one or more. This only changes what Lumen puts front and centre."
    ) {
      ForEach(PrimaryGoal.allCases) { item in
        Button {
          toggleGoal(item)
        } label: {
          HStack(spacing: 16) {
            Image(systemName: item.symbol)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(LumenTheme.accent)
              .frame(width: 46, height: 46)
              .background(
                LumenTheme.accent.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.headline)
              Text(item.detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: selectedGoals.contains(item) ? "checkmark.circle.fill" : "circle")
              .font(.title3)
              .foregroundStyle(
                selectedGoals.contains(item)
                  ? LumenTheme.accent : Color.secondary.opacity(0.45))
          }
          .padding(20)
          .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
              .strokeBorder(
                selectedGoals.contains(item)
                  ? LumenTheme.accent : Color.white.opacity(0.3),
                lineWidth: selectedGoals.contains(item) ? 1.5 : 0.5)
          }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedGoals.contains(item) ? .isSelected : [])
      }
    }
  }
  private var privacyStep: some View {
    scaffold(
      "Three optional switches.", "All optional. Nothing leaves the device either way."
    ) {
      PermissionOptionCard(
        isOn: $wantsAppLock,
        symbol: "faceid",
        tint: LumenTheme.lavender,
        title: "Lock with Face ID",
        detail: "Require a face or passcode to open.")
      PermissionOptionCard(
        isOn: $wantsHealthKit,
        symbol: "heart.text.square",
        tint: LumenTheme.blush,
        title: "Apple Health",
        detail: "Read & write cycle and temperature.")
      PermissionOptionCard(
        isOn: $wantsNotifications,
        symbol: "bell.badge",
        tint: LumenTheme.coral,
        title: "Local notifications",
        detail: "Period, fertile window, pill time.")
      Text(
        "Lumen has no network entitlement beyond CloudKit. You can verify that in the project entitlements and source."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 18)
      .padding(.vertical, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        Color.primary.opacity(0.04),
        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
      }
    }
    .tint(.green)
  }

  private var controls: some View {
    HStack {
      if step > 1 {
        Button {
          moveBackward()
        } label: {
          Image(systemName: "chevron.left").frame(width: 54, height: 54).background(
            .ultraThinMaterial, in: Circle())
        }
      }
      Button(step == 4 ? "Open Lumen" : "Continue") {
        if step == 4 { finish() } else { moveForward() }
      }.buttonStyle(PrimaryButtonStyle())
    }
  }

  @ViewBuilder private var currentStep: some View {
    switch step {
    case 0: welcome
    case 1: periodStep
    case 2: durationStep
    case 3: goalStep
    default: privacyStep
    }
  }

  private func moveForward() {
    navigationDirection = 1
    withAnimation(.easeInOut(duration: 0.38)) { step = min(4, step + 1) }
  }

  private func moveBackward() {
    navigationDirection = -1
    withAnimation(.easeInOut(duration: 0.38)) { step = max(0, step - 1) }
  }

  private func toggleGoal(_ goal: PrimaryGoal) {
    UISelectionFeedbackGenerator().selectionChanged()
    withAnimation(.easeInOut(duration: 0.2)) {
      if selectedGoals.contains(goal) {
        guard selectedGoals.count > 1 else { return }
        selectedGoals.remove(goal)
      } else {
        selectedGoals.insert(goal)
      }
    }
  }
  private func scaffold<Content: View>(
    _ title: String, _ detail: String, @ViewBuilder content: () -> Content
  ) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text(title).font(.title.bold()).padding(.top, 22)
        Text(detail).font(.callout).foregroundStyle(.secondary)
        VStack(spacing: 14) { content() }.padding(.top, 12)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 24)
    }
    .scrollBounceBehavior(.basedOnSize)
  }
  private func finish() {
    context.insert(CycleRecord(startDate: lastPeriod, periodDuration: periodDuration))
    if selectedGoals.contains(.birthControl) { context.insert(PillRegimen()) }
    try? context.save()
    UserDefaults.standard.set(periodDuration, forKey: "averagePeriodDuration")
    UserDefaults.standard.set(cycleLength, forKey: "averageCycleLength")
    let orderedGoals = PrimaryGoal.allCases.filter(selectedGoals.contains)
    UserDefaults.standard.set(orderedGoals.map(\.rawValue), forKey: "selectedGoals")
    UserDefaults.standard.set(orderedGoals.first?.rawValue, forKey: "primaryGoal")
    UserDefaults.standard.set(wantsAppLock, forKey: "appLockEnabled")
    UserDefaults.standard.set(wantsHealthKit, forKey: "healthReadEnabled")
    UserDefaults.standard.set(wantsHealthKit, forKey: "healthWriteEnabled")
    UserDefaults.standard.set(wantsNotifications, forKey: "notificationsEnabled")
    if wantsHealthKit {
      Task { _ = await health.requestAuthorization() }
    }
    if wantsNotifications, selectedGoals.contains(.birthControl) {
      Task {
        try? await NotificationManager.shared.schedulePillReminder(hour: 21, minute: 0)
      }
    }
    onFinish()
  }
}

private struct PermissionOptionCard: View {
  @Binding var isOn: Bool
  let symbol: String
  let tint: Color
  let title: String
  let detail: String

  var body: some View {
    Toggle(isOn: $isOn) {
      HStack(spacing: 14) {
        Image(systemName: symbol)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 40, height: 40)
          .background(
            tint.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.headline)
          Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
      }
    }
    .padding(20)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.07), radius: 16, y: 8)
  }
}

private struct DurationMetricCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(22)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
      }
      .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
  }
}

private struct DurationStepperHeader: View {
  let label: String
  let value: Int
  let tint: Color
  let onMinus: () -> Void
  let onPlus: () -> Void

  var body: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 4) {
        Text(label.uppercased())
          .font(.caption.weight(.semibold))
          .kerning(1)
          .foregroundStyle(.secondary)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("\(value)")
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
          Text("days").font(.title3).foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 12)
      HStack(spacing: 8) {
        DurationCircleButton(symbol: "minus", filled: false, tint: tint, action: onMinus)
        DurationCircleButton(symbol: "plus", filled: true, tint: tint, action: onPlus)
      }
    }
  }
}

private struct DurationCircleButton: View {
  let symbol: String
  let filled: Bool
  let tint: Color
  let action: () -> Void

  var body: some View {
    Button {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      withAnimation(.easeInOut(duration: 0.2)) { action() }
    } label: {
      Image(systemName: symbol)
        .font(.title3.weight(.medium))
        .foregroundStyle(filled ? Color.white : Color.secondary)
        .frame(width: 44, height: 44)
        .background(
          filled ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(0.05)),
          in: Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(symbol == "plus" ? "Increase" : "Decrease")
  }
}

private struct WelcomePrivacyRow: View {
  let symbol: String
  let tint: Color
  let title: String
  let detail: String

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: symbol)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 34, height: 34)
        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 11))
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.callout.weight(.semibold))
        Text(detail).font(.footnote).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.06), radius: 14, y: 7)
  }
}
