import Flutter
import UIKit
import Vision
import ImageIO
import AliyunOSSiOS
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self
    registerOCRChannel()
    registerOSSChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound, .badge])
  }

  private func registerOCRChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(name: "eatclean/ios_ocr", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognizeText" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let paths = args["paths"] as? [String] else {
        result(FlutterError(code: "invalid_args", message: "Missing image paths", details: nil))
        return
      }
      self?.performOCR(paths: paths, result: result)
    }
  }

  private func registerOSSChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(name: "eatclean/oss_upload", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "uploadImages" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Missing arguments", details: nil))
        return
      }
      self?.uploadImagesWithOSS(args: args, result: result)
    }
  }

  private func uploadImagesWithOSS(args: [String: Any], result: @escaping FlutterResult) {
    guard let paths = args["paths"] as? [String],
          let endpoint = args["endpoint"] as? String,
          let bucket = args["bucket"] as? String,
          let accessKeyId = args["accessKeyId"] as? String,
          let accessKeySecret = args["accessKeySecret"] as? String,
          let securityToken = args["securityToken"] as? String else {
      result(FlutterError(code: "invalid_args", message: "Missing OSS parameters", details: nil))
      return
    }
    let prefix = (args["prefix"] as? String) ?? "uploads"
    let userId = (args["userId"] as? Int) ?? 0

    DispatchQueue.global(qos: .userInitiated).async {
      let provider = OSSStsTokenCredentialProvider(accessKeyId: accessKeyId, secretKeyId: accessKeySecret, securityToken: securityToken)
      let client = OSSClient(endpoint: endpoint, credentialProvider: provider)
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy/MM/dd"
      let datePath = formatter.string(from: Date())
      let endpointHost = endpoint
        .replacingOccurrences(of: "https://", with: "")
        .replacingOccurrences(of: "http://", with: "")

      var urls: [String] = []
      for (index, path) in paths.enumerated() {
        let fileURL = URL(fileURLWithPath: path)
        let ext = fileURL.pathExtension.isEmpty ? "jpg" : fileURL.pathExtension
        let objectKey = "\(prefix)/\(userId)/\(datePath)/\(Int(Date().timeIntervalSince1970 * 1000))_\(index).\(ext)"

        let put = OSSPutObjectRequest()
        put.bucketName = bucket
        put.objectKey = objectKey
        put.uploadingFileURL = fileURL

        let task = client.putObject(put)
        task.waitUntilFinished()
        if let error = task.error {
          DispatchQueue.main.async {
            result(FlutterError(code: "oss_upload_failed", message: error.localizedDescription, details: nil))
          }
          return
        }

        let url = "https://\(bucket).\(endpointHost)/\(objectKey)"
        urls.append(url)
      }

      DispatchQueue.main.async {
        result(["urls": urls])
      }
    }
  }

  private func performOCR(paths: [String], result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      var outputs: [String] = []
      for path in paths {
        guard let image = UIImage(contentsOfFile: path) else { continue }
        if let text = self.recognizeText(in: image), !text.isEmpty {
          outputs.append(text)
        }
      }

      let combined = outputs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
      DispatchQueue.main.async {
        result(combined)
      }
    }
  }

  private func recognizeText(in image: UIImage) -> String? {
    guard let cgImage = image.cgImage else { return nil }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["zh-Hans", "en-US"]

    let handler = VNImageRequestHandler(
      cgImage: cgImage,
      orientation: cgOrientation(from: image.imageOrientation),
      options: [:]
    )

    do {
      try handler.perform([request])
      guard let observations = request.results as? [VNRecognizedTextObservation] else {
        return nil
      }
      let lines = observations.compactMap { $0.topCandidates(1).first?.string }
      return lines.joined(separator: "\n")
    } catch {
      return nil
    }
  }

  private func cgOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch orientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
