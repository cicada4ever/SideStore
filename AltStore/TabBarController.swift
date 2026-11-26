//
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

enum SideStoreAppearance: String, CaseIterable
{
    case system
    case light
    case dark

    static let defaultsKey = "SideStoreAppearance"

    static var current: SideStoreAppearance {
        SideStoreAppearance(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .system
    }

    var localizedName: String {
        switch self {
        case .system: return NSLocalizedString("System", comment: "")
        case .light: return NSLocalizedString("Light", comment: "")
        case .dark: return NSLocalizedString("Dark", comment: "")
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    func apply()
    {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
        for windowScene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }

    static func applyStoredPreference(to window: UIWindow?)
    {
        window?.overrideUserInterfaceStyle = current.interfaceStyle
    }
}

extension TabBarController
{
    private enum Tab: Int, CaseIterable
    {
        case myApps
        case settings
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?
    
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
        appsTab?.title = NSLocalizedString("Apps", comment: "")
        appsTab?.image = UIImage(systemName: "square.grid.2x2.fill")
        self.viewControllers?[Tab.settings.rawValue].tabBarItem.image = UIImage(systemName: "gearshape.fill")

        view.tintColor = .systemBlue
        tabBar.tintColor = .systemBlue
        SideStoreAppearance.applyStoredPreference(to: view.window)

        #if !os(tvOS)
        if #available(iOS 26.0, *) {
            // Keep the system tab bar so iOS can render its native Liquid Glass navigation layer.
            tabBar.isTranslucent = true
            tabBar.backgroundImage = nil
            tabBar.shadowImage = nil
        } else {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
        #endif
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")
        
        _viewDidAppear = true
        
        if let (identifier, sender) = self.initialSegue
        {
            self.initialSegue = nil
            self.performSegue(withIdentifier: identifier, sender: sender)
        }
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
