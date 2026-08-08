import LocalAuthentication
import SwiftUI

@Observable final class AppLockManager {
  var isUnlocked = false
  var errorMessage: String?
  var biometricName: String {
    let context = LAContext()
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    return context.biometryType == .faceID
      ? "Face ID" : context.biometryType == .touchID ? "Touch ID" : "device authentication"
  }

  func lock() { isUnlocked = false }
  func unlock() async {
    let context = LAContext()
    context.localizedCancelTitle = "Use Lumen without unlocking"
    do {
      isUnlocked = try await context.evaluatePolicy(
        .deviceOwnerAuthentication, localizedReason: "Unlock your private cycle data")
    } catch {
      errorMessage = error.localizedDescription
      isUnlocked = false
    }
  }
}
