import Flutter
import UIKit
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var offerPlayer: AVAudioPlayer?
  private var ringingOfferId: String?
  private var ringDeadline: Timer?
  private var offerChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      offerChannel = FlutterMethodChannel(
        name: "com.abdelaziz.visionway/booking_notification",
        binaryMessenger: controller.binaryMessenger
      )
      offerChannel?.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "startInstantOfferRing":
          if let id = args?["offerId"] as? String,
             let until = args?["untilMs"] as? NSNumber {
            self.startOfferRing(id: id, until: until.doubleValue / 1000)
          }
          result(nil)
        case "stopInstantOfferRing":
          if let id = args?["offerId"] as? String, id == self.ringingOfferId {
            self.stopOfferRing()
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    super.userNotificationCenter(center, willPresent: notification) { options in
      let type = notification.request.content.userInfo["type"] as? String
      // The visible request card owns the looping sound and stops it on answer.
      let isRequest = type == "instant_offer"
      completionHandler(isRequest ? options.subtracting(.sound) : options)
    }
  }

  private func startOfferRing(id: String, until: TimeInterval) {
    let remaining = until - Date().timeIntervalSince1970
    guard remaining > 0 else { return }
    stopOfferRing()
    guard let url = Bundle.main.url(forResource: "instant_offer_ring", withExtension: "wav") else { return }
    do {
      // Ambient respects the silent switch and mixes with other audio.
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      guard player.play() else { return }
      offerPlayer = player
      ringingOfferId = id
      ringDeadline = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
        self?.stopOfferRing()
      }
    } catch {
      stopOfferRing()
    }
  }

  private func stopOfferRing() {
    ringDeadline?.invalidate()
    ringDeadline = nil
    offerPlayer?.stop()
    offerPlayer = nil
    ringingOfferId = nil
  }
}
