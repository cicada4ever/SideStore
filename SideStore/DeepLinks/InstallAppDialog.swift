//
//  InstallAppDialog.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit

public enum AppImportSourceMode: String, CaseIterable, Identifiable, Sendable {
    case prompt = "prompt"
    case files  = "files"
    case url    = "url"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .prompt:
            return "Prompt User"
        case .files:
            #if !os(tvOS)
            return "Files App"
            #else
            return "Web Upload"
            #endif
        case .url:
            return "URL"
        }
    }
}

#if !os(tvOS)
@MainActor
private final class InstallAppSourceSheetViewController: UIViewController
{
    private let onChooseFiles: () -> Void
    private let onInstallURL: () -> Void

    init(onChooseFiles: @escaping () -> Void, onInstallURL: @escaping () -> Void)
    {
        self.onChooseFiles = onChooseFiles
        self.onInstallURL = onInstallURL
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("Install App", comment: "")
        titleLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: .systemFont(ofSize: 22, weight: .bold)
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.text = NSLocalizedString("Choose how you want to add an app.", comment: "")
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        header.axis = .vertical
        header.spacing = 5

        let filesButton = self.makeActionButton(
            title: NSLocalizedString("Choose from Files", comment: ""),
            symbol: "folder",
            action: self.onChooseFiles
        )
        let urlButton = self.makeActionButton(
            title: NSLocalizedString("Install from URL", comment: ""),
            symbol: "link",
            action: self.onInstallURL
        )

        let cancelButton = UIButton(type: .system)
        var cancelConfiguration = UIButton.Configuration.plain()
        cancelConfiguration.title = NSLocalizedString("Cancel", comment: "")
        cancelConfiguration.baseForegroundColor = .secondaryLabel
        cancelConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        cancelButton.configuration = cancelConfiguration
        cancelButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .primaryActionTriggered)

        let stack = UIStackView(arrangedSubviews: [header, filesButton, urlButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            filesButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            urlButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])

        if #available(iOS 15.0, *)
        {
            self.sheetPresentationController?.detents = [.medium(), .large()]
            self.sheetPresentationController?.prefersGrabberVisible = true
            self.sheetPresentationController?.prefersScrollingExpandsWhenScrolledToEdge = false
            self.sheetPresentationController?.preferredCornerRadius = 28
        }
    }

    private func makeActionButton(title: String, symbol: String, action: @escaping () -> Void) -> UIButton
    {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePlacement = .leading
        configuration.imagePadding = 12
        configuration.baseForegroundColor = .label
        configuration.baseBackgroundColor = .secondarySystemGroupedBackground
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true, completion: action)
        }, for: .primaryActionTriggered)
        return button
    }
}
#endif

@MainActor
public enum InstallAppDialog {
    
    public static func presentSourceSelection(
        from presentingVC: UIViewController,
        barButtonItem: UIBarButtonItem? = nil,
        mode: AppImportSourceMode = UserDefaults.standard.appImportSourceMode,
        onChooseFiles: @escaping () -> Void,
        onConfirm: @escaping (URL) -> Void
    ) {
        switch mode {
        case .prompt:
            #if !os(tvOS)
            let sourceSheet = InstallAppSourceSheetViewController(
                onChooseFiles: onChooseFiles,
                onInstallURL: {
                    self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
                }
            )
            presentingVC.present(sourceSheet, animated: true)
            #else
            let alertController = UIAlertController(
                title: NSLocalizedString("Install App", comment: ""),
                message: NSLocalizedString("Choose an installation method:", comment: ""),
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Upload via Web", comment: ""), style: .default) { _ in
                onChooseFiles()
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Install from URL", comment: ""), style: .default) { _ in
                self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
            })
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
            presentingVC.present(alertController, animated: true)
            #endif

        case .files:
            onChooseFiles()

        case .url:
            self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
        }
    }
    
    private static func presentURLInputDialog(
        from presentingVC: UIViewController,
        onConfirm: @escaping (URL) -> Void
    ) {
        let alert = UIAlertController(
            title: NSLocalizedString("Install from URL", comment: ""),
            message: NSLocalizedString("Enter the URL of the .ipa file to install.", comment: ""),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://example.com/app.ipa"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Continue", comment: ""), style: .default) { _ in
            guard let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  (scheme == "http" || scheme == "https") else {
                let errorAlert = UIAlertController(
                    title: NSLocalizedString("Invalid URL", comment: ""),
                    message: NSLocalizedString("Please enter a valid HTTP or HTTPS URL.", comment: ""),
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
                presentingVC.present(errorAlert, animated: true)
                return
            }
            
            self.present(ipaURL: url, from: presentingVC) {
                onConfirm(url)
            }
        })
        
        presentingVC.present(alert, animated: true)
    }
    
    public static func present(
        ipaURL: URL,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message: String
        if ipaURL.isFileURL {
            let appName = ipaURL.deletingPathExtension().lastPathComponent
            message = String(format: NSLocalizedString("Do you want to continue? This will install \"%@\".", comment: ""), appName)
        } else {
            message = String(format: NSLocalizedString("Do you want to continue? This will download and install from:\n%@", comment: ""), ipaURL.absoluteString)
        }
        
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    public static func present(
        storeApp: StoreApp,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message = String(format: NSLocalizedString("Do you want to continue? This will install \"%@\".", comment: ""), storeApp.name)
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }

    public static func present(
        installedApp: InstalledApp,
        from presentingViewController: UIViewController? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let message = String(format: NSLocalizedString("Do you want to continue? This will reinstall \"%@\".", comment: ""), installedApp.name)
        self.presentConfirmation(
            message: message,
            from: presentingViewController,
            onConfirm: onConfirm,
            onCancel: onCancel
        )
    }
    
    private static func presentConfirmation(
        message: String,
        from presentingViewController: UIViewController?,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        guard UserDefaults.standard.isInstallConfirmationEnabled else {
            onConfirm()
            return
        }
        
        let rootVC = presentingViewController ?? UIApplication.shared.topViewController()
        guard let presentingVC = rootVC else {
            onCancel()
            return
        }
        
        let alert = UIAlertController(
            title: NSLocalizedString("Install App", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("Install", comment: ""), style: .default) { _ in
            onConfirm()
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            onCancel()
        })
        
        presentingVC.present(alert, animated: true)
    }
}
