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

@MainActor
private final class InstallSourceSheetViewController: UIViewController
{
    private let onChooseFiles: () -> Void
    private let onChooseURL: () -> Void

    init(onChooseFiles: @escaping () -> Void, onChooseURL: @escaping () -> Void)
    {
        self.onChooseFiles = onChooseFiles
        self.onChooseURL = onChooseURL
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

        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("Install App", comment: "")
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let chooseFiles = onChooseFiles
        let chooseURL = onChooseURL

        let filesButton = makeButton(
            title: NSLocalizedString("From Files", comment: ""),
            symbol: "folder",
            primary: true
        )
        filesButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true, completion: chooseFiles)
        }, for: .primaryActionTriggered)

        let urlButton = makeButton(
            title: NSLocalizedString("From URL", comment: ""),
            symbol: "link",
            primary: false
        )
        urlButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true, completion: chooseURL)
        }, for: .primaryActionTriggered)

        let stack = UIStackView(arrangedSubviews: [titleLabel, filesButton, urlButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            filesButton.heightAnchor.constraint(equalToConstant: 52),
            urlButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func makeButton(title: String, symbol: String, primary: Bool) -> UIButton
    {
        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) {
            configuration = primary ? .prominentGlass() : .glass()
        } else {
            configuration = primary ? .filled() : .gray()
        }
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 10
        configuration.imagePlacement = .leading
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        if primary {
            configuration.baseBackgroundColor = .systemBlue
            configuration.baseForegroundColor = .white
        } else {
            configuration.baseBackgroundColor = .secondarySystemBackground
            configuration.baseForegroundColor = .label
        }

        let button = UIButton(configuration: configuration)
        button.tintColor = primary ? .systemBlue : .secondaryLabel
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.accessibilityLabel = title
        return button
    }
}

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
            let sheet = InstallSourceSheetViewController(
                onChooseFiles: onChooseFiles,
                onChooseURL: { [weak presentingVC] in
                    guard let presentingVC = presentingVC else { return }
                    self.presentURLInputDialog(from: presentingVC, onConfirm: onConfirm)
                }
            )
            if let presentationController = sheet.sheetPresentationController {
                presentationController.detents = [.medium()]
                presentationController.prefersGrabberVisible = true
                presentationController.preferredCornerRadius = 28
            }
            presentingVC.present(sheet, animated: true)
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
