import Flutter
import UIKit
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Campo para a view de bloqueio de screenshot
  private var secureField: UITextField?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ── Bloqueio de screenshot/gravação de tela ──────────────────────────────
    _applyScreenshotProtection()

    // Firebase é configurado automaticamente via GoogleService-Info.plist
    // FirebaseAppDelegateProxyEnabled = true no Info.plist cuida disso

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          print("🔔 Permissão notificações: \(granted)")
        }
      )
    }

    application.registerForRemoteNotifications()

    Messaging.messaging().delegate = self

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ── Proteção contra screenshot e gravação de tela ──────────────────────────
  //
  // Técnica: UITextField com isSecureTextEntry=true tem proteção nativa do iOS
  // contra captura de tela. Ao colocar a window inteira dentro da layer desse
  // campo, todo o conteúdo do app fica protegido.
  //
  // Resultado:
  //   - Screenshot → imagem preta/em branco
  //   - Screen recording (AirPlay, ReplayKit) → tela preta durante gravação
  //   - QuickTime via cabo → tela preta
  //
  private func _applyScreenshotProtection() {
    guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
          let window = windowScene.windows.first
    else { return }

    let field = UITextField()
    field.isSecureTextEntry = true
    field.translatesAutoresizingMaskIntoConstraints = false

    // A layer protegida do UITextField
    guard let secureLayer = field.layer.sublayers?.first else { return }
    secureLayer.frame = window.bounds

    // Insere a view protegida atrás de todo o conteúdo existente
    window.layer.insertSublayer(secureLayer, at: 0)
    secureField = field

    // Mantém o frame atualizado se a janela redimensionar (ex: iPad multitasking)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_updateSecureLayerFrame),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
  }

  @objc private func _updateSecureLayerFrame() {
    guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
          let window = windowScene.windows.first,
          let secureLayer = secureField?.layer.sublayers?.first
    else { return }

    secureLayer.frame = window.bounds
  }

  // Recebe APNs token
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("🍎 APNs token recebido")
    Messaging.messaging().apnsToken = deviceToken
  }

  // Erro APNs
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ APNs erro: \(error)")
  }
}

// Firebase Messaging Delegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📱 FCM token: \(fcmToken ?? "nil")")
  }
}