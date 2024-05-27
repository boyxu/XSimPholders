//
//  Application.swift
//  XSimPholders
//
//  Created by XuYingjie on 2024/5/28.
//

import Foundation

struct Application: Identifiable {
    
    let identifier: String
    let displayName: String
    let bundlePath: String
    let sandboxPath: String
    
    var id: String { identifier }
}
