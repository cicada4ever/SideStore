# SideStore SwiftUI Rewrite — Implementation Status

Base: `LiveContainerSupport`  
Branch: `feature/swiftui-rewrite`

## Implemented groundwork

- Added a standalone SwiftUI preview build workflow. It builds a uniquely versioned IPA and publishes a commit-specific prerelease named `swiftui-preview-<short-sha>`; it does not update the production `nightly` release.
- Extracted `InstalledAppsSortOption` from the UIKit My Apps controller while preserving its cases, raw values and localized labels.
- Added `InstalledAppsFeatureModel`, which observes the existing `DatabaseManager.shared.viewContext` through fetched-results controllers for active apps, inactive apps and supported updates. It preserves existing Core Data entities and persisted sort/grid preferences.
- Added `InstalledAppsOperations`, a presentation adapter forwarding install, refresh, update, activation/deactivation, delete, remove, backup/restore and JIT requests to the existing `AppManager`.
- Added `SideStoreMyAppsView`, a SwiftUI list/grid preview with search, sort, active/inactive/update sections, context menus, native app launch, existing AppViewController details, refresh, update, install-source selection, file import, backup/restore and JIT entry points.
- The SwiftUI preview now reuses the existing install-source preference, install confirmation, security-scoped file access and active-app limit candidate selection.
- Added `SideStoreMyAppsHostingController` and `InstallAppPresenting`, allowing the existing bottom-right install button to target either the UIKit controller or a future SwiftUI host without moving or repurposing that button.
- The original UIKit My Apps screen remains the production entry point. The new host is not wired into the live tab/navigation tree.

## Remaining feature parity before switching the default screen

- Unsupported updates, update expansion/release notes and refresh-all error summaries.
- Reinstall from cache/source, resign, alternate icons, app info and provisioning-profile changes.
- Full backup submenu: raw/ZIP export, import, previous-backup restore and backup deletion.
- App IDs, source management/browsing, pairing, imports/deep links and drag/drop parity.
- Contextual menu enabled/disabled states, inactive-app cleanup variants, accessibility/localization and responsive regression review.

Keep the current UIKit screen or bridge for any feature that is not yet migrated. Do not remove or bypass an existing action just because the SwiftUI screen compiles.

## Validation required

- [ ] Latest SideStore preview build passes with the SwiftUI model, operations adapter, view and host.
- [ ] Exact commit-specific preview release is published and downloadable.
- [ ] New view is manually exercised against real existing Core Data records.
- [ ] Search, sorting and layout preferences match the UIKit screen.
- [ ] App launch, activation/deactivation, active-app limit and pledge handling match.
- [ ] Install-source preference, confirmation, file access and URL import match.
- [ ] Update, resign, reinstall, JIT, App ID, profile and backup actions match.
- [ ] Standalone SideStore preview embeds into LiveContainer and passes combined-IPA checks.
- [ ] In-place installation over an existing combined app succeeds on a real device.

A feature is not complete because a view compiles. Verify its behavior and regression scenarios first.
