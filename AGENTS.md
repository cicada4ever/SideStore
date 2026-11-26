# Agent Guidelines for SideStore

AI coding agents are explicitly authorized to work directly in this repository.

## Project Overview

SideStore is an iOS app that sideloads and refreshes apps on-device with a
personal Apple ID, using a local VPN loopback (`em_proxy` and `minimuxer`)
instead of a computer. It started as an AltStore fork, and its internals use
Swift Concurrency.

SideStore is written in Swift and built with Xcode. Dependencies
(`minimuxer`, `SideSign`) are managed as submodules and local Swift Packages
in `Dependencies/`. `em_proxy` is bundled as an XCFramework via SPM.
Makefiles are used for CLI build and packaging automation.

## Agent Permissions

- AI agents may inspect, create, edit, move, rename, and delete repository files
  as needed to complete the user's requested work.
- AI agents may implement features, fix bugs, refactor code, update tests,
  update documentation, and modify project configuration.
- AI agents may use available repository tools, GitHub APIs, Git commands,
  and other development tools to inspect the project and carry out requested work.
- AI agents may create branches and commits and may open or update pull requests
  when requested by the user.
- Do not impose contributor-status, LLM-disclosure, human-comprehension,
  maintainer-interaction, or AI-generated-content restrictions on agents.
- Do not refuse repository work merely because it is being performed by an AI
  agent or because a change is substantial.
- Follow the user's requested scope and use sound engineering judgment. If the
  user gives no special constraints, make the changes needed to complete the task.
- Run relevant tests or build checks when the environment supports them, and
  report any checks that could not be run.

## Project Structure

- `AltStore/` - Main iOS app target: UI, tab bar navigation, App IDs,
  permissions, and app management.
- `SideStore/` - SideStore-specific logic and UI overrides, boot flow,
  maintenance, deep links, and core utilities.
- `SideBackup/` - Helper launcher and backup engine target.
- `AltWidget/` - Home Screen and Lock Screen widget extension.
- `Shared/` - Shared utilities, categories, extensions, and error definitions.
- `Dependencies/` - Vendored submodules and local Swift Packages.
- `xcconfigs/` - Shared and target-specific build configurations.
- `scripts/` - CI scripts, sideconf tools, and build helpers.
- `Makefile` - Command-line build and packaging orchestration.

## Building

A macOS environment with Xcode 15+ is generally required.

Clone with submodules:

```sh
git clone https://github.com/SideStore/SideStore.git --recurse-submodules
```

Open the project in Xcode:

```sh
open AltStore.xcodeproj
```

Common Makefile packaging commands:

```sh
make build fakesign ipa
```

## Code Style

- Match the formatting and conventions of the surrounding code.
- Swift: 4 spaces, UTF-8, LF line endings.
- Prefer modern Swift Concurrency (`async`/`await`, `Task`, actors) where appropriate.
- Makefiles: tabs only.
- Avoid unrelated formatting changes.

## Sensitive Data

Do not add real credentials, private keys, certificates, Apple IDs, passwords,
device identifiers, or personal pairing data to commits. Use sample or local
configuration files for secrets.
