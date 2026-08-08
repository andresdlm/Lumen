import SwiftUI

struct RootView: View {
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @AppStorage("appLockEnabled") private var appLockEnabled = false
  @AppStorage("hideInAppSwitcher") private var hideInAppSwitcher = true
  @Environment(\.scenePhase) private var scenePhase
  @Environment(AppLockManager.self) private var lock

  var body: some View {
    ZStack {
      if hasCompletedOnboarding {
        MainTabView()
      } else {
        OnboardingView { hasCompletedOnboarding = true }
      }
      if hasCompletedOnboarding && appLockEnabled && !lock.isUnlocked { LockView() }
      if hideInAppSwitcher && scenePhase != .active {
        Rectangle().fill(.ultraThinMaterial).ignoresSafeArea().overlay {
          Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(LumenTheme.accent)
        }
      }
    }
    .task { if !appLockEnabled { lock.isUnlocked = true } else { await lock.unlock() } }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background && appLockEnabled { lock.lock() }
    }
  }
}

private struct LockView: View {
  @Environment(AppLockManager.self) private var lock
  var body: some View {
    ZStack {
      AmbientBackground(phase: .fertile)
      VStack(spacing: 20) {
        Image(systemName: "lock.shield.fill").font(.system(size: 54)).foregroundStyle(
          LumenTheme.accent)
        Text("Lumen is locked").font(.title.bold())
        Text("Your cycle data stays private.").foregroundStyle(.secondary)
        Button("Unlock with \(lock.biometricName)") { Task { await lock.unlock() } }.buttonStyle(
          PrimaryButtonStyle()
        ).frame(maxWidth: 300)
        if let error = lock.errorMessage {
          Text(error).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
      }.padding(30)
    }
  }
}

struct MainTabView: View {
  @State private var selection = 0
  @State private var showingLog = false
  var body: some View {
    TabView(selection: $selection) {
      DashboardView(showingLog: $showingLog)
        .tabItem { Label("Today", systemImage: "circle.dotted") }
        .tag(0)
      CycleCalendarView()
        .tabItem { Label("Calendar", systemImage: "calendar") }
        .tag(1)
      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        .tag(2)
    }
    .tint(LumenTheme.accent)
    .sheet(isPresented: $showingLog) { DailyLogView(date: .now) }
  }
}
