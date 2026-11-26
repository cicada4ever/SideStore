import SwiftUI
import UIKit

@MainActor
final class SideStoreMyAppsCoordinator: ObservableObject {
    @Published var isInstallMenuPresented = false
}

/// SwiftUI implementation is kept behind the same install-presenter contract
/// as the legacy controller until its feature-parity checklist is complete.
@MainActor
final class SideStoreMyAppsHostingController: UIHostingController<SideStoreMyAppsView>, InstallAppPresenting {
    private let coordinator: SideStoreMyAppsCoordinator

    init() {
        let coordinator = SideStoreMyAppsCoordinator()
        self.coordinator = coordinator
        super.init(rootView: SideStoreMyAppsView(coordinator: coordinator))
    }

    required dynamic init?(coder aDecoder: NSCoder) {
        return nil
    }

    func presentInstallAppMenu() {
        coordinator.isInstallMenuPresented = true
    }
}
