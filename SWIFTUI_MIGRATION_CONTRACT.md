# SwiftUI Migration Contract — SideStore

Status: planning and compatibility guardrails  
Base: `LiveContainerSupport`  
Working branch: `feature/swiftui-rewrite`

## Objective

Move SideStore's user-facing application interface to a modern, maintainable SwiftUI architecture while preserving every existing feature and its behavior. This is a presentation-layer migration, not a rewrite of the signing, installation, refresh, authentication, networking, storage, or device-communication engines.

## Non-negotiable compatibility rules

1. Do not change the effective release bundle identifier. The current configuration derives it from `MAIN_BUNDLE_IDENTIFIER` (default release form: `com.SideStore.SideStore`). Do not hard-code a different value or remove the existing Debug/Release distinction.
2. Preserve the effective App Group identifier derived from `APP_GROUP_IDENTIFIER` (default release form: `group.com.SideStore.SideStore`). Preserve the matching entitlements for the app and widget targets.
3. Preserve the Keychain service identity based on `Bundle.Info.appbundleIdentifier`, all Keychain item names, accessibility/synchronizable settings, and existing Keychain migration behavior.
4. Preserve the Core Data store location under the SideStore App Group's `Database` directory, the Core Data model, all model versions and migration policies, entity names, attributes, relationships, and persistent-store options.
5. Preserve the SideStore App Group's `Backups` directory and existing backup/restore formats.
6. Preserve all existing UserDefaults keys, defaults, semantics, and migrations. UI bindings may change; persisted key names and meanings must not change without an explicit backward-compatible migration.
7. Preserve the `sidestore` and backup URL schemes, IPA/pairing document types, deep links, App Intents (`RefreshAllIntent`, `ViewAppIntent`), widget identifiers, notifications, background modes, and import/export behavior.
8. Do not change the SideSign, AltSign, Anisette, certificate provisioning, minimuxer, em_proxy, pairing, operations/pipeline, backup, refresh, or app-installation implementations as part of UI work.
9. Preserve the standalone SideStore IPA and the embedded SideStore packaging contract consumed by LiveContainer. Do not rename modules, intent types, products, targets, bundle IDs, App Groups, or extension IDs without updating and testing the integration contract in the LiveContainer fork.
10. Do not clear, recreate, move, rename, or replace user data as a UI migration shortcut.

## UI migration scope

Replace presentation progressively, keeping adapters to existing UIKit controllers and managers until equivalent SwiftUI screens are proven.

Required feature parity includes:

- My Apps: installed/inactive apps, update states, search, filtering, sorting, grid/list modes where supported, refresh, refresh-all, progress, installation, drag/drop, actions, app details, icons, deletion, import/export, and backup.
- Sources: source list, source details, browse/catalogue flows, source updates, adding/removing sources, and deep links.
- Authentication: Apple ID sign-in, verification, team selection, sign-out, account import/export, and errors.
- Installation and updates: file/URL/source installation, staging, signing, provisioning, progress, cancellation, retries, and actionable errors.
- App IDs and developer services: certificates, profiles, devices, app groups, and App ID management.
- Advanced features: pairing, wireless pairing, Anisette, SideJIT, minimuxer/em_proxy configuration, cache management, backup/restore, diagnostics, logs, permissions, and user customizations.
- Widgets, App Intents, shortcuts, notifications, background services, and URL/document handling.

No feature is considered migrated based solely on a screen existing. Every visible action must call the corresponding existing service and pass behavioral tests.

## Architecture direction

- Keep the current application lifecycle and critical UIKit delegates while migration is underway.
- Introduce a SwiftUI root/navigation layer through a small, explicit UIKit/SwiftUI boundary; do not replace the app lifecycle in one step.
- Separate feature views, presentation state, and adapters from existing engines.
- Prefer native SwiftUI controls and system navigation/presentation APIs. Retain UIKit for capabilities that still require it.
- Avoid multiple sources of truth. Existing Core Data and service managers remain authoritative.
- Keep long-running operations outside View bodies and expose observable progress, cancellation, and errors through adapters.

## Build and integration contract

The current `.github/workflows/nightly.yml` builds SideStore independently from `LiveContainerSupport` and publishes a nightly `SideStore.ipa`. LiveContainer's packaging workflow consumes that artifact and transforms/embeds it. Do not run experimental builds in a way that overwrites the known-good nightly release.

A separate non-publishing preview build path should be used for the rewrite branch. Only a verified build may be promoted to the shared nightly release.

## Required verification before removing legacy UI

- Build the standalone SideStore target and extensions.
- Verify app, widget, App Group, URL scheme, document type, and App Intent metadata identities.
- Test database open, migrations, model compatibility, and backup/restore using existing user data.
- Test sign-in, Keychain reads/writes, certificate access, Anisette, pairing, minimuxer/em_proxy, install, resign, refresh, refresh-all, source management, app IDs, JIT, widgets, shortcuts, and imports.
- Verify embedded SideStore remains loadable and callable by the current LiveContainer integration.
- Run UI tests and inspect on supported iPhone/iPad sizes, portrait/landscape, Light/Dark Mode, and accessibility settings.
- Remove a legacy screen only after the replacement passes the same behavior checklist.

## Data-safety release gate

A build is not complete merely because it compiles or launches on a clean install. The final combined LiveContainer + SideStore IPA must be installed **over an existing installation without deleting the old app first**. Before that test, preserve the current known-good IPA and make a user-controlled backup. After upgrade, verify existing SideStore credentials, pairing, databases, sources, installed-app records, certificates, app IDs, backup files, and preferences remain available.

If bundle identity, signing team/application-identifier prefix, App Group entitlement, Keychain access, or data-store compatibility cannot be verified, stop the release and report the blocker. Never claim data preservation without a successful in-place upgrade test on a real device.
