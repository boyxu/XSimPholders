//
//  Device.swift
//  XSimPholders
//
//  Created by XuYingjie on 2024/5/27.
//

import Foundation

struct Device: Identifiable {
    
    let osVersion: String
    let name: String
    let udid: String
    let path: String
    let state: String
    
    let applications: [Application]
    
    var id: String { udid }
}

struct OSDevices: Identifiable {
    let osVersion: String
    let devices: [Device]
    
    var id: String { osVersion }
}
