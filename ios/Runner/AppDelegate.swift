import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc func screenCaptureChanged() {
    guard let window = window else { return }

    if UIScreen.main.isCaptured {
      let overlay = UIView(frame: window.bounds)
      overlay.backgroundColor = .black
      overlay.alpha = 0.96
      overlay.tag = 9999
      overlay.isUserInteractionEnabled = false
      window.addSubview(overlay)
      return
    }

    window.viewWithTag(9999)?.removeFromSuperview()
  }

  @objc func userDidTakeScreenshot() {
    guard let window = window,
          let rootViewController = window.rootViewController else {
      return
    }

    let alert = UIAlertController(
      title: "Peringatan Keamanan",
      message: "Screenshot tidak diizinkan dalam mode ujian.",
      preferredStyle: .alert
    )
    alert.addAction(.init(title: "Kembali ke ujian", style: .default, handler: nil))
    rootViewController.present(alert, animated: true)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
