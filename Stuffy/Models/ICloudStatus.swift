import CloudKit
import Observation

/// Whether data can sync. Local storage keeps working when it can't.
@MainActor @Observable
final class ICloudStatus {
    private(set) var status: CKAccountStatus = .couldNotDetermine

    var isAvailable: Bool { status == .available }
    var message: String? {
        switch status {
        case .available, .couldNotDetermine: nil
        case .noAccount: "Sign in to iCloud in Settings to sync your stuff across devices. Until then it's saved on this device only."
        case .restricted: "iCloud is restricted on this device, so your stuff is saved here only."
        case .temporarilyUnavailable: "iCloud is temporarily unavailable. Sync will resume automatically."
        @unknown default: nil
        }
    }

    func refresh() async {
        status = (try? await CKContainer.default().accountStatus()) ?? .couldNotDetermine
    }
}
