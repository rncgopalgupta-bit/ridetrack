import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Google Maps SDK for iOS prior to any map view initialization
    var mapsApiKey = "AIzaSyBw1vVEA5KrJ8HIHSPod-cVywJ_JcerNtU"

    // 1. Check Info.plist if configured
    if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String, !plistKey.isEmpty {
      mapsApiKey = plistKey
    } else if let envPath = Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "flutter_assets") ??
                            Bundle.main.path(forResource: ".env", ofType: nil) {
      // 2. Fallback to bundled .env file
      if let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) {
        for line in envContent.components(separatedBy: .newlines) {
          let trimmed = line.trimmingCharacters(in: .whitespaces)
          if trimmed.hasPrefix("GOOGLE_MAPS_API_KEY=") {
            let extracted = trimmed.replacingOccurrences(of: "GOOGLE_MAPS_API_KEY=", with: "").trimmingCharacters(in: .whitespaces)
            if !extracted.isEmpty {
              mapsApiKey = extracted
            }
            break
          }
        }
      }
    }

    GMSServices.provideAPIKey(mapsApiKey)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

