import Combine
import CoreData
import Foundation

/// SwiftUI-facing projection of the existing SideStore Core Data database.
///
/// The database and its entities remain authoritative. This model only owns
/// fetched-results controllers and presentation preferences; it never creates,
/// deletes, migrates, or replaces the persistent store.
final class InstalledAppsFeatureModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published private(set) var activeApps: [InstalledApp] = []
    @Published private(set) var inactiveApps: [InstalledApp] = []
    @Published private(set) var appsWithUpdates: [InstalledApp] = []

    @Published var searchText = "" {
        didSet {
            guard searchText != oldValue else { return }
            applySearchAndSorting()
        }
    }

    @Published var sortOption: InstalledAppsSortOption {
        didSet {
            guard sortOption != oldValue else { return }
            UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortPreferenceKey)
            applySearchAndSorting()
        }
    }

    @Published var isGridLayout: Bool {
        didSet {
            guard isGridLayout != oldValue else { return }
            UserDefaults.standard.set(isGridLayout, forKey: Self.gridPreferenceKey)
        }
    }

    static let sortPreferenceKey = "SideStoreInstalledAppsSortOption"
    static let gridPreferenceKey = "SideStoreAppGridLayout"

    private let context: NSManagedObjectContext
    private let activeAppsController: NSFetchedResultsController<InstalledApp>
    private let inactiveAppsController: NSFetchedResultsController<InstalledApp>
    private let updatesController: NSFetchedResultsController<InstalledApp>

    private let activeBasePredicate: NSPredicate?
    private let inactiveBasePredicate: NSPredicate?
    private let updatesBasePredicate: NSPredicate?

    init(context: NSManagedObjectContext = DatabaseManager.shared.viewContext) {
        self.context = context

        let storedSort = UserDefaults.standard.string(forKey: Self.sortPreferenceKey) ?? ""
        self.sortOption = InstalledAppsSortOption(rawValue: storedSort) ?? .expiration
        self.isGridLayout = UserDefaults.standard.bool(forKey: Self.gridPreferenceKey)

        let activeRequest = InstalledApp.activeAppsFetchRequest()
        activeRequest.relationshipKeyPathsForPrefetching = [#keyPath(InstalledApp.storeApp)]
        activeRequest.returnsObjectsAsFaults = false
        self.activeBasePredicate = activeRequest.predicate

        let inactiveRequest = InstalledApp.fetchRequest()
        inactiveRequest.predicate = NSPredicate(format: "%K == NO", #keyPath(InstalledApp.isActive))
        inactiveRequest.relationshipKeyPathsForPrefetching = [#keyPath(InstalledApp.storeApp)]
        inactiveRequest.returnsObjectsAsFaults = false
        self.inactiveBasePredicate = inactiveRequest.predicate

        let updatesRequest = InstalledApp.supportedUpdatesFetchRequest()
        updatesRequest.relationshipKeyPathsForPrefetching = [#keyPath(InstalledApp.storeApp)]
        updatesRequest.returnsObjectsAsFaults = false
        self.updatesBasePredicate = updatesRequest.predicate

        self.activeAppsController = NSFetchedResultsController(
            fetchRequest: activeRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        self.inactiveAppsController = NSFetchedResultsController(
            fetchRequest: inactiveRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        self.updatesController = NSFetchedResultsController(
            fetchRequest: updatesRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        super.init()

        self.activeAppsController.delegate = self
        self.inactiveAppsController.delegate = self
        self.updatesController.delegate = self

        self.applySearchAndSorting()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.publishFetchedObjects(for: controller)
    }

    /// Refetch after an operation whose result changes membership or ordering.
    func reload() {
        self.applySearchAndSorting()
    }

    private func publishFetchedObjects(for controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if controller === self.activeAppsController {
            self.activeApps = self.activeAppsController.fetchedObjects ?? []
        } else if controller === self.inactiveAppsController {
            self.inactiveApps = self.inactiveAppsController.fetchedObjects ?? []
        } else if controller === self.updatesController {
            self.appsWithUpdates = self.updatesController.fetchedObjects ?? []
        }
    }

    private func applySearchAndSorting() {
        let term = self.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchPredicate: NSPredicate? = term.isEmpty ? nil : NSPredicate(
            format: "(%K CONTAINS[cd] %@) OR (%K CONTAINS[cd] %@)",
            #keyPath(InstalledApp.name), term,
            #keyPath(InstalledApp.bundleIdentifier), term
        )

        func combinedPredicate(base: NSPredicate?) -> NSPredicate? {
            guard let searchPredicate else { return base }
            guard let base else { return searchPredicate }
            return NSCompoundPredicate(andPredicateWithSubpredicates: [base, searchPredicate])
        }

        let nameDescriptor = NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)
        let sortDescriptors: [NSSortDescriptor]

        switch self.sortOption {
        case .expiration:
            sortDescriptors = [
                NSSortDescriptor(keyPath: \InstalledApp.expirationDate, ascending: true),
                NSSortDescriptor(keyPath: \InstalledApp.refreshedDate, ascending: false),
                nameDescriptor
            ]
        case .newest:
            sortDescriptors = [
                NSSortDescriptor(keyPath: \InstalledApp.installedDate, ascending: false),
                nameDescriptor
            ]
        case .oldest:
            sortDescriptors = [
                NSSortDescriptor(keyPath: \InstalledApp.installedDate, ascending: true),
                nameDescriptor
            ]
        case .recentlyRefreshed:
            sortDescriptors = [
                NSSortDescriptor(keyPath: \InstalledApp.refreshedDate, ascending: false),
                nameDescriptor
            ]
        case .name:
            sortDescriptors = [nameDescriptor]
        }

        self.activeAppsController.fetchRequest.predicate = combinedPredicate(base: self.activeBasePredicate)
        self.inactiveAppsController.fetchRequest.predicate = combinedPredicate(base: self.inactiveBasePredicate)
        self.activeAppsController.fetchRequest.sortDescriptors = sortDescriptors
        self.inactiveAppsController.fetchRequest.sortDescriptors = sortDescriptors
        self.updatesController.fetchRequest.predicate = self.updatesBasePredicate
        self.updatesController.fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \InstalledApp.storeApp?.latestSupportedVersion?.date, ascending: false),
            nameDescriptor
        ]

        do {
            try self.activeAppsController.performFetch()
            try self.inactiveAppsController.performFetch()
            try self.updatesController.performFetch()
            self.activeApps = self.activeAppsController.fetchedObjects ?? []
            self.inactiveApps = self.inactiveAppsController.fetchedObjects ?? []
            self.appsWithUpdates = self.updatesController.fetchedObjects ?? []
        } catch {
            debugLog("[SideStore] Failed to fetch installed apps for SwiftUI: \\(error)")
        }
    }
}
