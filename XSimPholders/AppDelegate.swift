//
//  AppDelegate.swift
//  XSimPholders
//
//  Created by 徐英杰 on 4/29/16.
//  Copyright © 2016 Yingjie Xu. All rights reserved.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    
    let popover = NSPopover()
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-2)
    var eventMonitor: EventMonitor?
    lazy var simulatorList: [Simulator] = Simulator.all
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        eventMonitor = EventMonitor(mask: [.LeftMouseDownMask, .RightMouseDownMask], handler: { [unowned self] event in
                if self.popover.shown {
                    self.closePopover(event)
                }
            })
        eventMonitor?.start()
        
        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarButtonImage")
            button.action = #selector(togglePopover(_:))
        }
        
        let menu = NSMenu()
        for simulator in simulatorList {
            let simulatorName = simulator.name
            
            let parentItem = NSMenuItem(title: simulatorName, action: nil, keyEquivalent: "")
            menu.addItem(parentItem)
            
            let subMenu = NSMenu()
            subMenu.delegate = self
            menu.setSubmenu(subMenu, forItem: parentItem)
            
            createAppItemFor(menu: subMenu, simulator: simulator)
        }
        menu.addItem(NSMenuItem.separatorItem())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    // MARK: Methods
    func refreshSubMenu(menu: NSMenu) {
        guard menu.supermenu == statusItem.menu else {
            return
        }
        menu.removeAllItems()
        let index = statusItem.menu?.indexOfItemWithSubmenu(menu)
        guard index != NSNotFound else {
            return
        }
        let simulator = simulatorList[index!]
        createAppItemFor(menu: menu, simulator: simulator)
    }
    
    func createAppItemFor(menu menu: NSMenu, simulator: Simulator) {
        let apps = simulator.userApplications()
        for j in 0 ..< apps.count {
            let app: SimulatorUserApplication = apps[j]
            let item = NSMenuItem(title: app.displayName, action: #selector(selectSimulator(_:)), keyEquivalent: "")
            let warpObject = WarpObject()
            warpObject.object = app
            item.representedObject = warpObject
            menu.addItem(item)
        }
    }
    
    // MARK: Actions
    func showPopover(sender: AnyObject?) {
        if let button = statusItem.button {
            popover.showRelativeToRect(button.bounds, ofView: button, preferredEdge: NSRectEdge.MinY)
        }
        eventMonitor?.start()
    }
    
    func closePopover(sender: AnyObject?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
    func togglePopover(sender: AnyObject?) {
        if popover.shown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func selectSimulator(sender: NSMenuItem) {
        guard let warpObject = sender.representedObject else {
            return
        }
        guard (warpObject.className).isEqual(WarpObject.className()) else {
            return
        }
        let warpApp = warpObject as! WarpObject
        let app: SimulatorUserApplication = warpApp.object as! SimulatorUserApplication
        
        let url = NSURL(fileURLWithPath: app.sandboxPath)
        NSWorkspace.sharedWorkspace().openURLs([url], withAppBundleIdentifier: "com.apple.Finder", options: .WithoutActivation, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
    }
    
    /*
    func generateMenuItemView() -> NSView? {
        var views: NSArray?
        let isHave = NSBundle.mainBundle().loadNibNamed("RecentAppItemView", owner: nil, topLevelObjects: &views)
        if isHave {
            let itemView = views?.lastObject
            return itemView as? NSView
        }
        let iconFile = "/Users/XuYingjie/Library/Developer/CoreSimulator/Devices/D846767B-57EB-40F8-BA67-BFA6ABCB949A/data/Containers/Bundle/Application/72DC4CCD-C6F8-49A7-8E2B-B9CF7FB2C43B/i8xiaoshi test.app/AppIcon40x40@2x.png"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 50))
        //view.wantsLayer = true
        //view.layer?.backgroundColor = NSColor.redColor().CGColor
        
        let icon = NSImageView(frame: NSRect(x: 16, y: 0, width: 50, height: 50))
        icon.imageFrameStyle = .None
        icon.image = NSImage(contentsOfFile: iconFile)
        view.addSubview(icon)
        let title = NSTextField(frame: NSRect(x: 74, y: 0, width: 50, height: 16))
        return view
    }
    */
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}


extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(menu: NSMenu) {
        
    }
    func menuWillOpen(menu: NSMenu) {
        refreshSubMenu(menu)
    }
    func menuDidClose(menu: NSMenu) {
        
    }
    
}

