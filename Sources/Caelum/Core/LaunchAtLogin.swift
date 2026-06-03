import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService` (macOS 13+). Only works from a registered
/// `.app` bundle; calls are guarded so the dev binary fails gracefully.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("Caelum: launch-at-login change failed: \(error.localizedDescription)")
            return false
        }
    }
}
