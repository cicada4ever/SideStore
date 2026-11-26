# SideStore SwiftUI Rewrite — Implementation Status

Base: `LiveContainerSupport`  
Branch: `feature/swiftui-rewrite`

## Implemented groundwork

- Added a standalone SwiftUI preview build workflow. It builds a versioned IPA artifact and publishes a commit-specific prerelease under `swiftui-preview-<short-sha>`; it does not update the production `nightly` release.
- Extracted `InstalledAppsSortOption` from the UIKit My Apps controller while preserving the original cases, raw values and localized labels.
- Added `InstalledAppsFeatureModel`, which observes the existing `DatabaseManager.shared.viewContext` with fetched-results controllers for active apps, inactive apps and apps with supported updates. It preserves the existing search predicate and persisted sort/grid preference keys.
- Added `InstalledAppsOperations`, a presentation adapter that forwards installation, refresh, update, activation/deactivation, deletion, backup/restore, removal and JIT requests to `AppManager.shared`. It does not contain a parallel signing or installation engine.

## Not yet migrated

- The existing UIKit My Apps screen remains the production screen.
- The new SwiftUI model and operations adapter are not yet wired into the app navigation.
- Feature parity remains incomplete for installation dialogs, update expansion, unsupported update handling, refresh-all, activation-limit prompts, source installation, drag/drop, import routes, app IDs, backups and diagnostics.
- No production IPA has been produced from this branch, and no device upgrade test has been performed.

## Validation required

- [ ] Latest SideStore preview build passes with the new model and adapter.
- [ ] The preview prerelease is available under its exact commit tag.
- [ ] The model displays existing records without resetting or migrating the database.
- [ ] Search and sorting match the existing UIKit screen.
- [ ] Every SwiftUI action calls the existing `AppManager` operation.
- [ ] Existing UIKit screens remain available until all behavior is migrated and verified.
- [ ] The SideStore preview embeds successfully into the LiveContainer modernization branch.
- [ ] In-place installation over an existing combined app is tested on a real device before release.

Do not mark a feature complete because a view compiles. Verify its behavior and regression scenarios first.
