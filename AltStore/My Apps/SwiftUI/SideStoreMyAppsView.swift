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
    @State private var isEnteringInstallURL = false
    @State private var installURLText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var confirmation: AppConfirmation?

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
        Group {
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
                        Label("List", systemImage: "list.bullet").tag(false)
                        Label("Grid", systemImage: "square.grid.2x2").tag(true)
                    }

                    Divider()

                    Button {
                        refreshAll()
                    } label: {
                        Label("Refresh All", systemImage: "arrow.clockwise")
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
            "Install App",
            isPresented: $coordinator.isInstallMenuPresented,
            titleVisibility: .visible
        ) {
            Button("Install from File", systemImage: "doc.badge.plus") {
                isImportingIPA = true
            }
            Button("Install from URL", systemImage: "link") {
                isEnteringInstallURL = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(
            isPresented: $isImportingIPA,
            allowedContentTypes: supportedIPAContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                install(from: url)
            case .failure(let error):
                presentError(error)
            }
        }
        .sheet(isPresented: $isEnteringInstallURL) {
            NavigationView {
                Form {
                    Section("App URL") {
                        TextField("https://example.com/app.ipa", text: $installURLText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                }
                .navigationTitle("Install from URL")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isEnteringInstallURL = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Install") {
                            installFromEnteredURL()
                        }
                        .disabled(!isValidInstallURL)
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert("Something Went Wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
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
        Button {
            select(app)
        } label: {
            Group {
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

    private func appContextMenu(_ app: InstalledApp) -> some View {
        Group {
            if app.isActive {
                Button {
                    refresh(app)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isManaging(app))

                if app.hasUpdate {
                    Button {
                        update(app)
                    } label: {
                        Label("Update", systemImage: "arrow.down.circle")
                    }
                    .disabled(isManaging(app))
                }

                Button {
                    confirmation = .deactivate(app)
                } label: {
                    Label("Deactivate", systemImage: "pause.circle")
                }
                .disabled(isManaging(app))
            } else {
                Button {
                    activate(app)
                } label: {
                    Label("Activate", systemImage: "checkmark.circle")
                }
                .disabled(isManaging(app))
            }

            Button {
                backup(app)
            } label: {
                Label("Back Up", systemImage: "archivebox")
            }
            .disabled(isManaging(app))

            Button {
                confirmation = .restore(app)
            } label: {
                Label("Restore Backup", systemImage: "arrow.uturn.backward")
            }
            .disabled(isManaging(app))

            Button {
                enableJIT(app)
            } label: {
                Label("Enable JIT", systemImage: "bolt")
            }
            .disabled(isManaging(app))

            if app.bundleIdentifier != Bundle.Info.appbundleIdentifier {
                Divider()

                Button(role: .destructive) {
                    confirmation = .remove(app)
                } label: {
                    Label("Remove from SideStore", systemImage: "minus.circle")
                }
                .disabled(isManaging(app))

                Button(role: .destructive) {
                    confirmation = .delete(app)
                } label: {
                    Label("Delete from Device", systemImage: "trash")
                }
                .disabled(isManaging(app))
            }
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
        Label(title, systemImage: symbol)
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

    private func select(_ app: InstalledApp) {
        guard let presenter else { return }

        if !app.isSideloaded, let storeApp = app.storeApp {
            let details = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "appViewController") as! AppViewController
            details.app = storeApp
            presenter.navigationController?.pushViewController(details, animated: true)
        } else {
            UIApplication.shared.open(app.openAppURL) { success in
                if !success {
                    DispatchQueue.main.async {
                        self.presentErrorMessage("Unable to open \(app.name).")
                    }
                }
            }
        }
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
            presentErrorMessage("There are no apps available to refresh.")
            return
        }

        let group = operations.refresh(apps, presentingViewController: presenter)
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

    private func update(_ app: InstalledApp) {
        guard let presenter else { return }
        operations.update(app, presentingViewController: presenter) { result in
            self.complete(result)
        }
    }

    private func activate(_ app: InstalledApp) {
        guard let presenter else { return }
        operations.activate(app, presentingViewController: presenter) { result in
            self.complete(result)
        }
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
        operations.removeFromSideStore(app, presentingViewController: presenter) { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self.presentError(error)
                }
                self.model.reload()
            }
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

    private func install(from url: URL) {
        guard let presenter else {
            presentErrorMessage("The install interface is not ready yet.")
            return
        }

        let accessGranted = url.startAccessingSecurityScopedResource()
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

    private func installFromEnteredURL() {
        let value = installURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value) else {
            presentErrorMessage("Enter a valid app URL.")
            return
        }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            presentErrorMessage("The app URL must use HTTP or HTTPS.")
            return
        }

        isEnteringInstallURL = false
        install(from: url)
    }

    private var isValidInstallURL: Bool {
        guard let url = URL(string: installURLText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
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
        case .delete(let app): return "Delete \(app.name) from your device?"
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
            return "The app record will be removed from SideStore. This does not uninstall the app from your device."
        case .delete:
            return "This removes the installed app from your device. Make sure you have a backup if you need its data."
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
            Button("Deactivate", role: .destructive) { deactivate(app) }
        case .remove(let app):
            Button("Remove from SideStore", role: .destructive) { removeFromSideStore(app) }
        case .delete(let app):
            Button("Delete from Device", role: .destructive) { deleteFromDevice(app) }
        case .backup(let app):
            Button("Back Up", role: .none) { backup(app) }
        case .restore(let app):
            Button("Restore", role: .destructive) { restore(app) }
        case nil:
            EmptyView()
        }

        Button("Cancel", role: .cancel) {
            confirmation = nil
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
        Group {
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
