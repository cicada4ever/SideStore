import CoreData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
struct SideStoreMyAppsView: View {
    @StateObject private var model: InstalledAppsFeatureModel
    @ObservedObject private var appManager = AppManager.shared
    @ObservedObject var coordinator: SideStoreMyAppsCoordinator

    @State private var presenter: UIViewController?
    @State private var isImportingIPA = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var confirmation: AppConfirmation?
    @State private var showAppLimitPrompt = false
    @State private var pendingActivationApp: InstalledApp?
    @State private var activationCandidates: [InstalledApp] = []

    private let operations = InstalledAppsOperations()

    private let gridColumns = [
        GridItem(.adaptive(minimum: 84, maximum: 112), spacing: 18, alignment: .top)
    ]

    init(
        coordinator: SideStoreMyAppsCoordinator,
        model: InstalledAppsFeatureModel = InstalledAppsFeatureModel()
    ) {
        self.coordinator = coordinator
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        SwiftUI.Group {
            if model.isGridLayout {
                gridContent
            } else {
                listContent
            }
        }
        .navigationTitle("My Apps")
        .searchable(text: $model.searchText, prompt: "Search apps")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $model.sortOption) {
                        ForEach(InstalledAppsSortOption.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }

                    Picker("Layout", selection: $model.isGridLayout) {
                        SwiftUI.Label("List", systemImage: "list.bullet").tag(false)
                        SwiftUI.Label("Grid", systemImage: "square.grid.2x2").tag(true)
                    }

                    Divider()

                    SwiftUI.Button {
                        refreshAll()
                    } label: {
                        SwiftUI.Label("Refresh All", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .accessibilityLabel("More Options")
                }
            }
        }
        .background {
            SideStorePresenterAnchor { controller in
                self.presenter = controller
            }
            .frame(width: 0, height: 0)
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: confirmationPresented,
            titleVisibility: .visible
        ) {
            confirmationButtons
        } message: {
            Text(confirmationMessage)
        }
        .confirmationDialog(
            activationLimitTitle,
            isPresented: $showAppLimitPrompt,
            titleVisibility: .visible
        ) {
            ForEach(activationCandidates, id: \.objectID) { candidate in
                SwiftUI.Button(action: { deactivateForActivationLimit(candidate) }) {
                    Text(candidate.name)
                }
            }
            SwiftUI.Button("Cancel", role: .cancel) {
                pendingActivationApp = nil
                activationCandidates = []
            }
        } message: {
            Text(activationLimitMessage)
        }
        .onChange(of: coordinator.isInstallMenuPresented) { isPresented in
            guard isPresented else { return }
            coordinator.isInstallMenuPresented = false
            presentInstallSourceSelection()
        }
        .fileImporter(
            isPresented: $isImportingIPA,
            allowedContentTypes: supportedIPAContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard let presenter else {
                    presentErrorMessage("The install interface is not ready yet.")
                    return
                }
                let accessGranted = url.startAccessingSecurityScopedResource()
                InstallAppDialog.present(ipaURL: url, from: presenter) {
                    self.install(from: url, securityScopeAlreadyStarted: accessGranted)
                } onCancel: {
                    if accessGranted { url.stopAccessingSecurityScopedResource() }
                }
            case .failure(let error):
                presentError(error)
            }
        }
        .alert("Something Went Wrong", isPresented: $showError) {
            SwiftUI.Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppManager.didFetchSourceNotification)) { _ in
            model.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.importAppDeepLinkNotification)) { notification in
            guard let url = notification.userInfo?[AppDelegate.importAppDeepLinkURLKey] as? URL else {
                return
            }
            install(from: url)
        }
    }

    private var listContent: some View {
        List {
            if !model.appsWithUpdates.isEmpty {
                Section("Updates Available") {
                    ForEach(model.appsWithUpdates, id: \.objectID) { app in
                        appRow(app)
                    }
                }
            }

            let activeApps = model.activeApps.filter { !$0.hasUpdate }
            if !activeApps.isEmpty {
                Section("Active Apps") {
                    ForEach(activeApps, id: \.objectID) { app in
                        appRow(app)
                    }
                }
            }

            if !model.inactiveApps.isEmpty {
                Section("Inactive Apps") {
                    ForEach(model.inactiveApps, id: \.objectID) { app in
                        appRow(app)
                    }
                }
            }

            if model.activeApps.isEmpty && model.inactiveApps.isEmpty {
                Section {
                    ContentEmptyState(
                        title: "No Apps Yet",
                        message: "Install an app to see it here.",
                        symbol: "square.stack.3d.up"
                    )
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var gridContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if !model.appsWithUpdates.isEmpty {
                    appGridSection("Updates Available", apps: model.appsWithUpdates)
                }

                let activeApps = model.activeApps.filter { !$0.hasUpdate }
                if !activeApps.isEmpty {
                    appGridSection("Active Apps", apps: activeApps)
                }

                if !model.inactiveApps.isEmpty {
                    appGridSection("Inactive Apps", apps: model.inactiveApps)
                }

                if model.activeApps.isEmpty && model.inactiveApps.isEmpty {
                    ContentEmptyState(
                        title: "No Apps Yet",
                        message: "Install an app to see it here.",
                        symbol: "square.stack.3d.up"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func appGridSection(_ title: String, apps: [InstalledApp]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 22) {
                ForEach(apps, id: \.objectID) { app in
                    appCell(app, isGrid: true)
                }
            }
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        appCell(app, isGrid: false)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private func appCell(_ app: InstalledApp, isGrid: Bool) -> some View {
        SwiftUI.Button {
            select(app)
        } label: {
            SwiftUI.Group {
                if isGrid {
                    VStack(spacing: 7) {
                        appIcon(app, size: 62)
                        Text(app.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Text(app.version)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        appStatus(app, compact: true)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                } else {
                    HStack(spacing: 13) {
                        appIcon(app, size: 54)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text("\(app.version) · \(app.bundleIdentifier)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            appStatus(app, compact: false)

                            if let progress = progress(for: app) {
                                if progress.isIndeterminate {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    ProgressView(value: progress.fractionCompleted)
                                        .tint(.accentColor)
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(app.name), \(app.version)")
        .contextMenu {
            appContextMenu(app)
        }
    }

    @ViewBuilder
    private func appContextMenu(_ app: InstalledApp) -> some View {
        if app.isActive {
            SwiftUI.Button(action: { refresh(app) }) {
                SwiftUI.Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isManaging(app) || isPledgeInactive(app))

            if app.hasUpdate {
                SwiftUI.Button(action: { update(app) }) {
                    SwiftUI.Label("Update", systemImage: "arrow.down.circle")
                }
                .disabled(isManaging(app) || isPledgeInactive(app))
            }

            SwiftUI.Button(action: { confirmation = .deactivate(app) }) {
                SwiftUI.Label("Deactivate", systemImage: "pause.circle")
            }
            .disabled(isManaging(app))

            if app.bundleIdentifier != Bundle.Info.appbundleIdentifier {
                SwiftUI.Button(action: { confirmation = .delete(app) }) {
                    SwiftUI.Label("Delete App", systemImage: "trash")
                }
                .disabled(isManaging(app) || isPledgeInactive(app))
            }

            SwiftUI.Button(action: { enableJIT(app) }) {
                SwiftUI.Label("Enable JIT", systemImage: "bolt")
            }
            .disabled(isManaging(app) || isPledgeInactive(app))
        } else {
            SwiftUI.Button(action: { activate(app) }) {
                SwiftUI.Label("Activate", systemImage: "checkmark.circle")
            }
            .disabled(isManaging(app) || isPledgeInactive(app))

            if shouldOfferRemoveForInactiveApp(app) {
                SwiftUI.Button(action: { confirmation = .remove(app) }) {
                    SwiftUI.Label("Remove", systemImage: "minus.circle")
                }
                .disabled(isManaging(app))
            }
        }

        if app.isActive || (!UserDefaults.standard.isLegacyDeactivationSupported && UTType(app.installedAppUTI) != nil) {
            SwiftUI.Button(action: { backup(app) }) {
                SwiftUI.Label("Create Backup", systemImage: "archivebox")
            }
            .disabled(isManaging(app))

            SwiftUI.Button(action: { confirmation = .restore(app) }) {
                SwiftUI.Label("Restore Backup", systemImage: "arrow.uturn.backward")
            }
            .disabled(isManaging(app))
        }
    }

    @ViewBuilder
    private func appStatus(_ app: InstalledApp, compact: Bool) -> some View {
        HStack(spacing: 6) {
            if app.hasUpdate {
                statusLabel("Update available", symbol: "arrow.down.circle.fill", color: Color(uiColor: .systemOrange), compact: compact)
            } else if !app.isActive {
                statusLabel("Inactive", symbol: "pause.circle", color: .secondary, compact: compact)
            } else if Date() > app.expirationDate {
                statusLabel("Expired", symbol: "exclamationmark.triangle.fill", color: Color(uiColor: .systemRed), compact: compact)
            } else if app.certificateStatus == .revoked {
                statusLabel("Certificate revoked", symbol: "xmark.circle.fill", color: Color(uiColor: .systemRed), compact: compact)
            } else {
                statusLabel("Active", symbol: "checkmark.circle.fill", color: Color(uiColor: .systemGreen), compact: compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
    }

    private func statusLabel(
        _ title: LocalizedStringKey,
        symbol: String,
        color: Color,
        compact: Bool
    ) -> some View {
        SwiftUI.Label(title, systemImage: symbol)
            .font(compact ? .caption2 : .caption)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private func appIcon(_ app: InstalledApp, size: CGFloat) -> some View {
        InstalledAppIconView(app: app, size: size)
    }

    private func progress(for app: InstalledApp) -> Progress? {
        appManager.installationProgress(for: app) ?? appManager.refreshProgress(for: app)
    }

    private func isManaging(_ app: InstalledApp) -> Bool {
        appManager.isActivelyManagingApp(withBundleID: app.bundleIdentifier)
    }

    private func isPledgeInactive(_ app: InstalledApp) -> Bool {
        guard let storeApp = app.storeApp else { return false }
        return storeApp.isPledgeRequired && !storeApp.isPledged
    }

    private func select(_ app: InstalledApp) {
        guard let presenter else { return }

        if !app.isActive {
            activate(app)
            return
        }

        if app.hasUpdate, let storeApp = app.storeApp {
            let details = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "appViewController") as! AppViewController
            details.app = storeApp
            presenter.navigationController?.pushViewController(details, animated: true)
            return
        }

        UIApplication.shared.open(app.openAppURL) { success in
            if !success {
                DispatchQueue.main.async {
                    self.presentErrorMessage("Unable to open \\(app.name).")
                }
            }
        }
    }

    private func shouldOfferRemoveForInactiveApp(_ app: InstalledApp) -> Bool {
        if (UserDefaults.standard.legacySideloadedApps ?? []).contains(app.bundleIdentifier) {
            return true
        }
        return !UserDefaults.standard.isLegacyDeactivationSupported
    }

    private func presentInstallSourceSelection() {
        guard let presenter else {
            presentErrorMessage("The install interface is not ready yet.")
            return
        }

        InstallAppDialog.presentSourceSelection(
            from: presenter,
            mode: UserDefaults.standard.appImportSourceMode,
            onChooseFiles: {
                isImportingIPA = true
            },
            onConfirm: { url in
                install(from: url)
            }
        )
    }

    private func refresh(_ app: InstalledApp) {
        guard let presenter else { return }
        let group = operations.refresh([app], presentingViewController: presenter)
        group.completionHandler = { results in
            let failure = results.values.compactMap { result -> Error? in
                if case .failure(let error) = result, !(error is CancellationError) {
                    return error
                }
                return nil
            }.first
            DispatchQueue.main.async {
                if let failure {
                    self.presentError(failure)
                }
                self.model.reload()
            }
        }
    }

    private func refreshAll() {
        guard let presenter else { return }
        let apps = InstalledApp.fetchAppsForRefreshingAll(in: DatabaseManager.shared.viewContext)
        guard !apps.isEmpty else {
            let error: Error
            if let sideStoreApp = InstalledApp.fetchAltStore(in: DatabaseManager.shared.viewContext),
               let storeApp = sideStoreApp.storeApp,
               storeApp.isPledgeRequired && !storeApp.isPledged {
                error = OperationError.pledgeInactive(appName: sideStoreApp.name)
            } else {
                error = OperationError.noInstalledApps
            }
            presentError(error)
            return
        }

        let group = operations.refresh(apps, presentingViewController: presenter)
        group.completionHandler = { results in
            let failures = results.compactMapValues { result -> Error? in
                if case .failure(let error) = result, !(error is CancellationError) {
                    return error
                }
                return nil
            }
            DispatchQueue.main.async {
                if !failures.isEmpty {
                    let detail = failures.values.first?.localizedDescription ?? "Unknown error"
                    self.presentErrorMessage("Failed to refresh \\(failures.count) app(s). \\(detail)")
                }
                self.model.reload()
            }
        }
    }

    private func update(_ app: InstalledApp) {
        guard let presenter else { return }
        operations.update(app, presentingViewController: presenter) { result in
            self.complete(result)
        }
    }

    private func activate(_ app: InstalledApp) {
        pendingActivationApp = app
        continueActivationIfNeeded()
    }

    private func continueActivationIfNeeded() {
        guard let app = pendingActivationApp else { return }

        if let candidates = AppManager.shared.appsToDeactivate(for: app) {
            guard !candidates.isEmpty else {
                pendingActivationApp = nil
                presentErrorMessage("SideStore's active-app limit has been reached, and there are no eligible apps to deactivate.")
                return
            }
            activationCandidates = candidates
            showAppLimitPrompt = true
            return
        }

        guard let presenter else {
            pendingActivationApp = nil
            presentErrorMessage("The activation interface is not ready yet.")
            return
        }

        pendingActivationApp = nil
        activationCandidates = []
        operations.activate(app, presentingViewController: presenter) { result in
            self.complete(result)
        }
    }

    private func deactivateForActivationLimit(_ candidate: InstalledApp) {
        guard let presenter else {
            pendingActivationApp = nil
            return
        }

        // Match the legacy prompt: mark the candidate inactive before asking
        // AppManager to deactivate it, so the next active-slot calculation sees
        // the pending state. Restore it if the operation fails.
        candidate.isActive = false
        operations.deactivate(candidate, presentingViewController: presenter) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let context = candidate.managedObjectContext, context.hasChanges {
                        try? context.save()
                    }
                    self.model.reload()
                    self.continueActivationIfNeeded()
                case .failure(let error):
                    candidate.managedObjectContext?.perform {
                        candidate.isActive = true
                        try? candidate.managedObjectContext?.save()
                    }
                    self.pendingActivationApp = nil
                    self.activationCandidates = []
                    if !(error is CancellationError) {
                        self.presentError(error)
                    }
                }
            }
        }
    }

    private var activationLimitTitle: String {
        guard let app = pendingActivationApp,
              UserDefaults.standard.activeAppLimitIncludesExtensions,
              !app.appExtensions.isEmpty else {
            return "Cannot Activate More than 3 Apps"
        }
        return "Cannot Activate More than 3 Apps and App Extensions"
    }

    private var activationLimitMessage: String {
        guard let app = pendingActivationApp,
              UserDefaults.standard.activeAppLimitIncludesExtensions,
              !app.appExtensions.isEmpty else {
            return "Non-developer Apple IDs are limited to 3 active apps. Please choose an app to deactivate."
        }

        let count = app.appExtensions.count
        let extensionText = count == 1 ? "app extension" : "app extensions"
        return "Non-developer Apple IDs are limited to 3 active apps and app extensions. \\(app.name) contains \\(count) \\(extensionText). Please choose an app to deactivate."
    }

    private func deactivate(_ app: InstalledApp) {
        guard let presenter else { return }
        operations.deactivate(app, presentingViewController: presenter) { result in
            self.complete(result)
        }
    }

    private func deleteFromDevice(_ app: InstalledApp) {
        guard let presenter else { return }
        operations.deleteFromDevice(app, presentingViewController: presenter) { result in
            self.complete(result)
        }
    }

    private func removeFromSideStore(_ app: InstalledApp) {
        let completion: (Result<Void, Error>) -> Void = { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self.presentError(error)
                }
                self.model.reload()
            }
        }

        if app.isActive {
            operations.removeFromSideStore(app, presentingViewController: presenter, completionHandler: completion)
        } else {
            operations.removeDeactivatedFromSideStore(app, completionHandler: completion)
        }
    }

    private func backup(_ app: InstalledApp) {
        guard let presenter else { return }
        operations.backup(app, presentingViewController: presenter) { result in
            self.complete(result)
        }
    }

    private func restore(_ app: InstalledApp) {
        guard let presenter else { return }
        operations.restore(app, presentingViewController: presenter) { result in
            self.complete(result)
        }
    }

    private func enableJIT(_ app: InstalledApp) {
        operations.enableJIT(for: app) { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self.presentError(error)
                } else {
                    self.model.reload()
                }
            }
        }
    }

    private func install(from url: URL, securityScopeAlreadyStarted: Bool = false) {
        guard let presenter else {
            if securityScopeAlreadyStarted { url.stopAccessingSecurityScopedResource() }
            presentErrorMessage("The install interface is not ready yet.")
            return
        }

        let accessGranted = securityScopeAlreadyStarted || url.startAccessingSecurityScopedResource()
        _ = operations.install(from: url, presentingViewController: presenter) { result in
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
            DispatchQueue.main.async {
                if case .failure(let error) = result, !(error is CancellationError) {
                    self.presentError(error)
                }
                self.model.reload()
            }
        }
    }

    private var supportedIPAContentTypes: [UTType] {
        let types = UTType.types(tag: "ipa", tagClass: .filenameExtension, conformingTo: nil)
        return types.isEmpty ? [.data] : types
    }

    private func complete(_ result: Result<InstalledApp, Error>) {
        let failure: Error?
        switch result {
        case .success:
            failure = nil
        case .failure(let error) where error is CancellationError:
            failure = nil
        case .failure(let error):
            failure = error
        }

        DispatchQueue.main.async {
            if let failure {
                self.presentError(failure)
            }
            self.model.reload()
        }
    }

    private func presentError(_ error: Error) {
        presentErrorMessage(error.localizedDescription)
    }

    private func presentErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .deactivate(let app): return "Deactivate \(app.name)?"
        case .remove(let app): return "Remove \(app.name) from SideStore?"
        case .delete(let app): return "Delete “\(app.name)”?"
        case .backup(let app): return "Back Up \(app.name)?"
        case .restore(let app): return "Restore \(app.name)?"
        case nil: return "Confirm Action"
        }
    }

    private var confirmationMessage: String {
        switch confirmation {
        case .deactivate:
            return "The app will remain installed but will no longer be active in SideStore."
        case .remove:
            return UserDefaults.standard.isLegacyDeactivationSupported
                ? "You must also delete the app from the Home Screen to fully uninstall it."
                : "This will remove the app from SideStore and erase any backup data for this app."
        case .delete:
            return "This will remove the app from SideStore and erase its backup. Choose Remove to keep the app on your device, or Delete to uninstall it."
        case .backup:
            return "Create a backup using SideStore's existing backup operation."
        case .restore:
            return "Restore this app using its existing SideStore backup."
        case nil:
            return ""
        }
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        switch confirmation {
        case .deactivate(let app):
            SwiftUI.Button(action: { deactivate(app) }) {
                Text("Deactivate")
            }
            .tint(.red)
        case .remove(let app):
            SwiftUI.Button(action: { removeFromSideStore(app) }) {
                Text("Remove from SideStore")
            }
            .tint(.red)
        case .delete(let app):
            SwiftUI.Button(action: { removeFromSideStore(app) }) {
                Text("Remove")
            }
            .tint(.red)
            SwiftUI.Button(action: { deleteFromDevice(app) }) {
                Text("Delete")
            }
            .tint(.red)
        case .backup(let app):
            SwiftUI.Button(action: { backup(app) }) {
                Text("Back Up")
            }
        case .restore(let app):
            SwiftUI.Button(action: { restore(app) }) {
                Text("Restore")
            }
            .tint(.red)
        case nil:
            EmptyView()
        }

        SwiftUI.Button(action: { confirmation = nil }) {
            Text("Cancel")
        }
    }
}

private enum AppConfirmation {
    case deactivate(InstalledApp)
    case remove(InstalledApp)
    case delete(InstalledApp)
    case backup(InstalledApp)
    case restore(InstalledApp)
}

private struct InstalledAppIconView: View {
    let app: InstalledApp
    let size: CGFloat
    @State private var icon: UIImage?

    var body: some View {
        SwiftUI.Group {
            if let icon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.tertiary)
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .task(id: app.objectID) {
            do {
                icon = try await app.loadIcon()
            } catch {
                icon = nil
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ContentEmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let symbol: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct SideStorePresenterAnchor: UIViewControllerRepresentable {
    let onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
            onResolve(controller)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
