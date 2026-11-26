# SideStore — SwiftUI Feature-Parity Register

Base branch: `LiveContainerSupport`  
Rewrite branch: `feature/swiftui-rewrite`  
Status: inventory started; no feature migration is considered complete yet.

This register is the source-of-truth checklist for replacing the presentation layer. Check an item only after its new SwiftUI implementation has been tested against the existing behavior and verified in the standalone IPA and the combined LiveContainer + SideStore IPA.

## Application shell and lifecycle

- [ ] App launch, boot sequence, first-run state and onboarding
- [ ] UIKit scene lifecycle and restoration behavior
- [ ] Main tabs, navigation stacks, title behavior and install entry point
- [ ] Overflow menus, app-level menus and contextual actions
- [ ] App URL schemes and deep-link routing
- [ ] File/document import for IPA, pairing and supported file types
- [ ] App Intents, Shortcuts, notifications and background refresh
- [ ] Widget data publication and widget extension behavior
- [ ] Error presentation, logging, crash recovery and diagnostics

Existing integration points: `AltStore/AppDelegate.swift`, `AltStore/SceneDelegate.swift`, `AltStore/TabBarController.swift`, `SideStore/DeepLinks/`, `AltWidget/`.

## My Apps and installed-app management

- [ ] Installed app collection, app metadata and app icons
- [ ] App grid and list layouts, with persisted layout preference
- [ ] Active, inactive, update-available and unsupported sections
- [ ] Search, filtering, sorting and section expansion
- [ ] Refresh individual app
- [ ] Refresh all apps and refresh groups
- [ ] Expiration state and expiration warnings
- [ ] Installation from IPA file
- [ ] Installation from URL and source
- [ ] Staging, signing, provisioning and extension bundle-ID preparation
- [ ] Installation progress, step reporting, cancellation and recoverable errors
- [ ] App details, app actions, deletion and app icon changes
- [ ] Drag/drop and reordering behaviors where currently supported
- [ ] App ID management entry points
- [ ] Backup creation, restore, removal and backup status
- [ ] Empty, loading, failed and offline states
- [ ] Accessibility, Dynamic Type and iPad/landscape behavior

Existing source of truth: `AltStore/My Apps/MyAppsViewController.swift`, installed-app/Core Data models, SideStore operation pipelines, and `SideStore/Views/MyApps/`. The new view must not become a second installation or refresh engine.

## Sources and app catalogue

- [ ] Sources list, source metadata and source ordering
- [ ] Add source, validate source, update source and remove source
- [ ] Source detail and app catalogue browsing
- [ ] Featured/catalogue screens and app detail navigation
- [ ] Source refresh, network errors and malformed-source handling
- [ ] Open source/app deep links and universal links
- [ ] Preserve known-source metadata and source-related Core Data migrations

Existing areas: `AltStore/Sources/`, `AltStore/Browse/`, `AltStore/Core/Model/Source.swift`, `SideStore/Core/Operations/StandaloneOperations/FetchSourceOperation.swift`.

## Authentication, signing and developer identity

- [ ] Apple ID sign-in and authentication challenges
- [ ] Account verification and team selection
- [ ] Sign out, import account, export account and account repair
- [ ] Certificate creation, renewal, selection, export and revocation
- [ ] App IDs, devices, profiles and app groups
- [ ] Developer portal requests and provisioning flows
- [ ] ADI and Anisette data, server selection and validation
- [ ] Existing Keychain read/write and legacy credential migration
- [ ] Certificate/password access from embedded LiveContainer
- [ ] Error and retry paths for authentication/signing failures

Existing services remain authoritative: `SideStore/Core/Auth/`, `SideStore/Core/Certificates/`, `SideStore/Core/Profiles/`, `SideStore/Core/Anisette/`, `AltStore/Core/Components/Keychain.swift`, and existing UIKit authentication flows.

## Device connectivity, refresh and background operations

- [ ] Pairing file import, replacement and validation
- [ ] Wireless pairing and Bonjour discovery
- [ ] Minimuxer configuration, startup, shutdown and status
- [ ] em_proxy configuration and VPN/loopback behavior
- [ ] SideJIT configuration and enabling JIT
- [ ] Background refresh and background service state
- [ ] Refresh notification scheduling and delivery
- [ ] Operation queues/pipelines, progress, retry and cancellation
- [ ] Refresh from standalone SideStore
- [ ] Refresh from embedded SideStore through SideStoreSupport and LiveProcess

Existing services remain authoritative: `SideStore/Core/Pairing/`, `SideStore/Core/Bonjour/`, `SideStore/Core/DeviceApi/`, `SideStore/Core/JIT/`, `SideStore/Core/Operations/`, `SideStore/AppBootManager.swift`, and `SideStoreSupport/` in LiveContainer.

## Settings, maintenance and advanced tools

- [ ] General appearance and user customization
- [ ] App icon selection and app display settings
- [ ] Pairing-file management
- [ ] Certificate and profile management
- [ ] Developer services and App ID management
- [ ] Cache management
- [ ] Backup and restore management
- [ ] Anisette configuration and diagnostics
- [ ] Network discovery and connection settings
- [ ] Console, operation and error logs
- [ ] Health checks and storage explorer
- [ ] Experimental/developer options and permissions
- [ ] License, about and support screens

Existing SwiftUI settings views should be reused where sound; UIKit-only presentation should be replaced only after parity tests pass.

## Required regression scenarios

- [ ] Fresh install and first launch
- [ ] Upgrade existing SideStore over itself without deleting it
- [ ] Existing Apple ID session and Keychain values still accessible
- [ ] Existing certificates, profiles and App IDs still present
- [ ] Existing pairing and Anisette state still present
- [ ] Existing Core Data database opens without reset and migrations complete
- [ ] Existing sources and installed-app records remain
- [ ] Install new IPA, update existing app, resign and remove an app
- [ ] Refresh one app and all apps
- [ ] Restore from existing backup and create a new backup
- [ ] App Intents, widget extension, notifications and URL/file imports
- [ ] Build standalone SideStore IPA
- [ ] Embed that IPA into LiveContainer and pass combined-IPA verifier
- [ ] In-place installation of the combined IPA over the current LiveContainer install

## Removal rule

A UIKit controller/storyboard/XIB is removable only when its replacement implements all of its existing user-visible actions, uses the existing service layer, and passes the corresponding regression scenarios. Do not delete an existing path merely because a SwiftUI screen compiles.
