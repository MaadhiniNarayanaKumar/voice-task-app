import AppIntents
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    IntentChannel.shared.attach(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

final class IntentChannel {
  static let shared = IntentChannel()
  private var channel: FlutterMethodChannel?
  private var pendingText: String?

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mia/intents", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "getPending" {
        result(self?.pendingText)
        self?.pendingText = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    deliverPending()
  }

  func handle(text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    pendingText = trimmed
    deliverPending()
  }

  func handle(url: URL) {
    if let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first(where: { $0.name == "text" })?
      .value {
      handle(text: text)
    }
  }

  private func deliverPending() {
    guard let channel, let pendingText else { return }
    channel.invokeMethod("addTask", arguments: pendingText)
    self.pendingText = nil
  }
}
