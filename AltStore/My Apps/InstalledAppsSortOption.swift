import Foundation

enum InstalledAppsSortOption: String, CaseIterable, Identifiable
{
    case expiration
    case newest
    case oldest
    case recentlyRefreshed
    case name

    var title: String
    {
        switch self
        {
        case .expiration: return NSLocalizedString("Expiration Soonest", comment: "")
        case .newest: return NSLocalizedString("Newest", comment: "")
        case .oldest: return NSLocalizedString("Oldest", comment: "")
        case .recentlyRefreshed: return NSLocalizedString("Recently Refreshed", comment: "")
        case .name: return NSLocalizedString("Name", comment: "")
        }
    }
    var id: String { rawValue }
}
