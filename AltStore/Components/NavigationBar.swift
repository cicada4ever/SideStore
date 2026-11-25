//
//  NavigationBar.swift
//  AltStore
//
//  Created by Riley Testut on 7/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit


class NavigationBarAppearance: UINavigationBarAppearance
{
    // We sometimes need to ignore user interaction so
    // we can tap items underneath the navigation bar.
    var ignoresUserInteraction: Bool = false
    
    override func copy(with zone: NSZone? = nil) -> Any
    {
        let copy = super.copy(with: zone) as! NavigationBarAppearance
        copy.ignoresUserInteraction = self.ignoresUserInteraction
        return copy
    }
}

class NavigationBar: UINavigationBar
{    
    @IBInspectable var automaticallyAdjustsItemPositions: Bool = true
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    private func initialize()
    {
        #if os(tvOS)
        if let tintColor = self.barTintColor {
            self.barTintColor = tintColor
            self.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        }
        #endif
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView?
    {
        #if !os(tvOS)
        if let appearance = self.topItem?.standardAppearance as? NavigationBarAppearance, appearance.ignoresUserInteraction
        {
            // Ignore touches.
            return nil
        }
        #endif
        
        return super.hitTest(point, with: event)
    }
}
