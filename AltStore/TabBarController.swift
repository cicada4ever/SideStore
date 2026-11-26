//
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

extension TabBarController
{
    private enum Tab: Int, CaseIterable
    {
        case myApps
        case settings
    }
}

final class TabBarController: UITabBarController, UITabBarControllerDelegate
{
    private var initialSegue: (identifier: String, sender: Any?)?
    private var installAppButton: UIButton?
    
    private var _viewDidAppear = false
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.importApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }
    
    override func viewDidLoad() 
    {
        super.viewDidLoad()
        debugLog("[TabBarController] viewDidLoad()")
        
        let appsTab = self.viewControllers?[Tab.myApps.rawValue].tabBarItem
        appsTab?.title = NSLocalizedString("My Apps", comment: "")
        appsTab?.image = UIImage(systemName: "square.stack.3d.up.fill")
        self.viewControllers?[Tab.settings.rawValue].tabBarItem.image = UIImage(systemName: "gearshape.fill")

        self.delegate = self
        self.tabBar.itemPositioning = .centered
        self.tabBar.itemWidth = 78
        self.tabBar.itemSpacing = 12

        let installButton = UIButton(type: .system)
        var configuration = UIButton.Configuration.bordered()
        configuration.image = UIImage(systemName: "plus")
        configuration.imagePadding = 0
        configuration.baseForegroundColor = .label
        configuration.baseBackgroundColor = .secondarySystemBackground
        configuration.cornerStyle = .capsule
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        installButton.configuration = configuration
        installButton.translatesAutoresizingMaskIntoConstraints = false
        installButton.accessibilityLabel = NSLocalizedString("Install App", comment: "")
        installButton.accessibilityHint = NSLocalizedString("Choose an app file or install from a URL.", comment: "")
        installButton.layer.borderWidth = 0.5
        installButton.addTarget(self, action: #selector(installAppTapped), for: .primaryActionTriggered)

        self.tabBar.addSubview(installButton)
        NSLayoutConstraint.activate([
            installButton.trailingAnchor.constraint(equalTo: self.tabBar.trailingAnchor, constant: -12),
            installButton.centerYAnchor.constraint(equalTo: self.tabBar.centerYAnchor),
            installButton.widthAnchor.constraint(equalToConstant: 54),
            installButton.heightAnchor.constraint(equalToConstant: 54)
        ])
        self.installAppButton = installButton
        self.updateInstallButtonAppearance()
        self.updateInstallButtonVisibility()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.updateInstallButtonVisibility()
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")
        self.updateInstallButtonVisibility()
        
        _viewDidAppear = true
        
        if let (identifier, sender) = self.initialSegue
        {
            self.initialSegue = nil
            self.performSegue(withIdentifier: identifier, sender: sender)
        }
    }
    
    private func updateInstallButtonVisibility()
    {
        let isMyAppsRootVisible: Bool
        if
            self.selectedIndex == Tab.myApps.rawValue,
            let navigationController = self.viewControllers?[Tab.myApps.rawValue] as? UINavigationController
        {
            isMyAppsRootVisible = navigationController.visibleViewController is InstallAppPresenting
        }
        else
        {
            isMyAppsRootVisible = false
        }

        self.installAppButton?.isHidden = !isMyAppsRootVisible
    }

    private func updateInstallButtonAppearance()
    {
        self.installAppButton?.layer.borderColor = UIColor.separator
            .resolvedColor(with: self.traitCollection)
            .cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        guard
            previousTraitCollection == nil ||
            self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection)
        else { return }
        self.updateInstallButtonAppearance()
    }

    @objc private func installAppTapped()
    {
        guard
            let navigationController = self.viewControllers?[Tab.myApps.rawValue] as? UINavigationController,
            let installPresenter = navigationController.viewControllers.first as? InstallAppPresenting
        else { return }

        installPresenter.presentInstallAppMenu()
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController)
    {
        self.updateInstallButtonVisibility()
    }

    override func performSegue(withIdentifier identifier: String, sender: Any?)
    {
        guard _viewDidAppear else {
            self.initialSegue = (identifier, sender)
            return
        }
        
        super.performSegue(withIdentifier: identifier, sender: sender)
    }
}

extension TabBarController
{
    @objc func presentSources(_ sender: Any)
    {
        guard let sourcesNavigationController = UIStoryboard(name: "Sources", bundle: nil)
            .instantiateInitialViewController() as? UINavigationController else {
            self.selectedIndex = Tab.settings.rawValue
            return
        }

        sourcesNavigationController.modalPresentationStyle = .pageSheet
        self.present(sourcesNavigationController, animated: true)
    }
}

private extension TabBarController
{
    @objc func importApp(_ notification: Notification)
    {
        self.selectedIndex = Tab.myApps.rawValue
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
    }
}
