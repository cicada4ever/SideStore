import Foundation
import UIKit

/// Presentation-layer adapter for the existing SideStore app-operation engine.
///
/// All work is forwarded to AppManager. This type deliberately contains no
/// signing, provisioning, installation, refresh, backup, or persistence logic.
@MainActor
struct InstalledAppsOperations {
    func install(
        from url: URL,
        presentingViewController: UIViewController,
        completionHandler: @escaping (Result<InstalledApp, Error>) -> Void
    ) -> RefreshGroup {
        AppManager.shared.install(
            .url(url),
            presentingViewController: presentingViewController,
            completionHandler: completionHandler
        )
    }

    func install(
        app: StoreApp,
        presentingViewController: UIViewController,
        completionHandler: @escaping (Result<InstalledApp, Error>) -> Void
    ) -> RefreshGroup {
        AppManager.shared.install(
            .app(app),
            presentingViewController: presentingViewController,
            completionHandler: completionHandler
        )
    }

    func refresh(
        _ apps: [InstalledApp],
        presentingViewController: UIViewController,
        group: RefreshGroup? = nil
    ) -> RefreshGroup {
        AppManager.shared.refresh(
            apps,
            presentingViewController: presentingViewController,
            group: group
        )
    }

    @discardableResult
    func update(
        _ app: InstalledApp,
        presentingViewController: UIViewController,
        completionHandler: @escaping (Result<InstalledApp, Error>) -> Void
    ) -> Progress {
        AppManager.shared.update(
            app,
            presentingViewController: presentingViewController,
            completionHandler: completionHandler
        )
    }

    func activate(
        _ app: InstalledApp,
        presentingViewController: UIViewController,
        completionHandler: @escaping (Result<InstalledApp, Error>) -> Void
    ) {
        AppManager.shared.activate(
            app,
            presentingViewController: presentingViewController
        ) { result in
            if case .success(let activatedApp) = result {
                activatedApp.managedObjectContext?.perform {
                    activatedApp.isActive = true
                    try? activatedApp.managedObjectContext?.save()
                }
            }
            completionHandler(result)
        }
    }

    func deactivate(
        _ app: InstalledApp,
        presentingViewController: UIViewController,
        completionHandler: @escaping (Result<InstalledApp, Error>) -> Void
    ) {
        AppManager.shared.deactivate(
            app,
            presentingViewController: presentingViewController
        ) { result in
            if case .success(let deactivatedApp) = result {
                deactivatedApp.managedObjectContext?.perform {
                    try? deactivatedApp.managedObjectContext?.save()
                }
            }
            completionHandler(result)
        }
    }

    func deleteFromDevice(
        _ app: InstalledApp,
        presentingViewController: UIViewController,
        completionHandler: @escaping (Result<InstalledApp, Error>) -> Void
    ) {
        AppManager.shared.deleteApp(
            app,
            presentingViewController: presentingViewController
        ) { result in
            if case .success(let deletedApp) = result {
                deletedApp.managedObjectContext?.perform {
                    try? deletedApp.managedObjectContext?.save()
                }
            }
            completionHandler(result)
        }
    }

    func backup(
        _ app: InstalledApp,
        presentingViewController: UIViewController,
        completionHandler: @escaping (Result<InstalledApp, Error>) -> Void
    ) {
        AppManager.shared.backup(
            app,
            presentingViewController: presentingViewController,
            completionHandler: completionHandler
        )
    }

    func restore(
        _ app: InstalledApp,
        presentingViewController: UIViewController,
        completionHandler: @escaping (Result<InstalledApp, Error>) -> Void
    ) {
        AppManager.shared.restore(
            app,
            presentingViewController: presentingViewController,
            completionHandler: completionHandler
        )
    }

    func removeFromSideStore(
        _ app: InstalledApp,
        presentingViewController: UIViewController? = nil,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        AppManager.shared.removeApp(
            app,
            presentingViewController: presentingViewController,
            completionHandler: completionHandler
        )
    }

    func enableJIT(
        for app: InstalledApp,
        completionHandler: @escaping (Result<Void, Error>) -> Void
    ) {
        AppManager.shared.enableJIT(for: app, completionHandler: completionHandler)
    }
}
