import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // Blur the app content when it enters the multitasking switcher (app snapshot)
  func sceneWillResignActive(_ scene: UIScene) {
    guard let windowScene = scene as? UIWindowScene,
          let window = windowScene.windows.first else { return }
    addPrivacyOverlay(to: window)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    guard let windowScene = scene as? UIWindowScene,
          let window = windowScene.windows.first else { return }
    removePrivacyOverlay(from: window)
  }

  private func addPrivacyOverlay(to window: UIWindow) {
    guard window.viewWithTag(8888) == nil else { return }
    let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    overlay.frame = window.bounds
    overlay.tag = 8888
    overlay.isUserInteractionEnabled = false
    window.addSubview(overlay)
  }

  private func removePrivacyOverlay(from window: UIWindow) {
    window.viewWithTag(8888)?.removeFromSuperview()
  }
}
