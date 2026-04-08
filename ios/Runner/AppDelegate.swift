import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Detect screen recording / AirPlay mirroring → show black overlay
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    // Detect screenshot → show warning dialog
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    // Blur when app goes to background (app switcher snapshot protection)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Screen capture / recording

  @objc func screenCaptureChanged() {
    guard let window = window else { return }
    if UIScreen.main.isCaptured {
      addBlackOverlay(to: window, tag: 9999)
    } else {
      window.viewWithTag(9999)?.removeFromSuperview()
    }
  }

  @objc func userDidTakeScreenshot() {
    guard let window = window,
          let rootVC = window.rootViewController else { return }
    let alert = UIAlertController(
      title: "Peringatan Keamanan",
      message: "Screenshot tidak diizinkan dalam mode ujian.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Kembali ke Ujian", style: .default))
    rootVC.present(alert, animated: true)
  }

  // MARK: - App switcher privacy blur

  @objc func appWillResignActive() {
    guard let window = window else { return }
    addBlurOverlay(to: window, tag: 8888)
  }

  @objc func appDidBecomeActive() {
    window?.viewWithTag(8888)?.removeFromSuperview()
  }

  // MARK: - Helpers

  private func addBlackOverlay(to window: UIWindow, tag: Int) {
    guard window.viewWithTag(tag) == nil else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .black
    overlay.alpha = 0.97
    overlay.tag = tag
    overlay.isUserInteractionEnabled = false
    window.addSubview(overlay)
  }

  private func addBlurOverlay(to window: UIWindow, tag: Int) {
    guard window.viewWithTag(tag) == nil else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    blur.frame = window.bounds
    blur.tag = tag
    blur.isUserInteractionEnabled = false
    window.addSubview(blur)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
