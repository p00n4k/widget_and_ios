import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ตั้งค่าภาษาเริ่มต้นของแอปให้เป็นภาษาไทย
    if let preferredLanguage = Locale.preferredLanguages.first {
        if preferredLanguage.contains("th") {
            application.accessibilityLanguage = "th"
        }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
