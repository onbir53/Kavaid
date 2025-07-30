import Flutter
import UIKit
import Firebase
// import GoogleMobileAds // AdMob banı nedeniyle geçici olarak devre dışı

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase konfigürasyonu
    FirebaseApp.configure()
    
    // AdMob geçici olarak devre dışı (ban nedeniyle)
    // Ban kalkınca şu satırı aktif hale getir:
    // GADMobileAds.sharedInstance().start(completionHandler: nil)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
