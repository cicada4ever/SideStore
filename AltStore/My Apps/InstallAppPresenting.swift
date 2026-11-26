import UIKit

/// Receives the existing tab-bar install action.
///
/// Both the legacy UIKit My Apps screen and the future SwiftUI hosting
/// controller can implement this contract without changing the button.
@MainActor
protocol InstallAppPresenting: AnyObject {
    func presentInstallAppMenu()
}

extension MyAppsViewController: InstallAppPresenting {}
