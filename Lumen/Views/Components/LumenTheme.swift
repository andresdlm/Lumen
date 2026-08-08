import SwiftUI

enum LumenTheme {
  static let blush = Color(red: 0.85, green: 0.29, blue: 0.40)
  static let lavender = Color(red: 0.55, green: 0.44, blue: 0.90)
  static let mint = Color(red: 0.29, green: 0.72, blue: 0.65)
  static let sand = Color(red: 0.92, green: 0.74, blue: 0.42)
  static let coral = Color(red: 0.98, green: 0.55, blue: 0.42)
  static let accent = Color(red: 0.72, green: 0.28, blue: 0.47)
}

extension CyclePhase {
  var tint: Color {
    switch self {
    case .menstrual: LumenTheme.blush
    case .follicular: LumenTheme.lavender
    case .fertile, .ovulation: LumenTheme.mint
    case .luteal: LumenTheme.sand
    }
  }
}

struct GlassCard<Content: View>: View {
  var padding: CGFloat = 18
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(padding)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(
          .white.opacity(0.35), lineWidth: 0.5)
      }
      .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
  }
}

struct AmbientBackground: View {
  let phase: CyclePhase
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        backgroundColor
        Circle()
          .fill(LumenTheme.blush.opacity(colorScheme == .dark ? 0.14 : 0.17))
          .frame(width: 440)
          .blur(radius: 125)
          .offset(x: -90, y: -330)
        Circle()
          .fill(LumenTheme.lavender.opacity(colorScheme == .dark ? 0.11 : 0.13))
          .frame(width: 410)
          .blur(radius: 135)
          .offset(x: 175, y: -35)
        Circle()
          .fill(phase.tint.opacity(colorScheme == .dark ? 0.1 : 0.12))
          .frame(width: 560)
          .blur(radius: 145)
          .offset(x: -105, y: 440)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }

  private var backgroundColor: Color {
    colorScheme == .dark
      ? Color(.systemGroupedBackground)
      : Color(red: 0.985, green: 0.972, blue: 0.976)
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.headline).foregroundStyle(.white).frame(
      maxWidth: .infinity, minHeight: 56
    )
    .background(LumenTheme.accent, in: Capsule()).shadow(
      color: LumenTheme.accent.opacity(0.35), radius: 14, y: 7
    )
    .scaleEffect(configuration.isPressed ? 0.97 : 1)
  }
}
