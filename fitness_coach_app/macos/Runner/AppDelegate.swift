import Cocoa
import FlutterMacOS
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Force macOS to show the camera permission dialog immediately on launch.
    // Without this, the Flutter camera plugin may hang silently in the sandbox.
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    if status == .notDetermined {
      AVCaptureDevice.requestAccess(for: .video) { granted in
        NSLog("[AppDelegate] Camera access \(granted ? "granted" : "denied")")
      }
    } else {
      NSLog("[AppDelegate] Camera auth status: \(status.rawValue)")
    }
    super.applicationDidFinishLaunching(notification)
  }
}
