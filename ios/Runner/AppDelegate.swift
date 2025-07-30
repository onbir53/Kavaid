import Flutter
import UIKit
import Firebase
import GoogleMobileAds

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase konfigürasyonu
    FirebaseApp.configure()
    
    // Google Mobile Ads SDK'yı başlat
    GoogleMobileAds.GADMobileAds.sharedInstance().start(completionHandler: nil)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
