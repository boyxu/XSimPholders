//
//  EventMonitor.swift
//  XSimPholders
//
//  Created by 徐英杰 on 4/30/16.
//  Copyright © 2016 Yingjie Xu. All rights reserved.
//

import Cocoa

class EventMonitor {
    private var monitor: AnyObject?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> ()
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> ()) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as AnyObject?
    }
    
    public func stop() {
        if monitor != nil {
            NSEvent.removeMonitor(monitor!)
            monitor = nil
        }
    }
}
