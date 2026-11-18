import Flutter
import flutter_local_notifications
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UNUserNotificationCenterDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)
    guard let registrar = registry.registrar(forPlugin: "QuevaaNotificationSettings") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.quevaa.quevaa/notification_settings",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let settingsURL: String
      if #available(iOS 15.4, *) {
        settingsURL = UIApplication.openNotificationSettingsURLString
      } else {
        settingsURL = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: settingsURL) else {
        result(false)
        return
      }
      UIApplication.shared.open(url) { opened in result(opened) }
    }
  }
}
