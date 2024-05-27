//
//  SimFinder.swift
//  XSimPholders
//
//  Created by 徐英杰 on 4/30/16.
//  Copyright © 2016 Yingjie Xu. All rights reserved.
//

import Cocoa
import SwiftyJSON

//CalculateSize
extension FileManager {
    func fileSize(for path: String) -> UInt64 {
        if !fileExists(atPath: path) {
            return 0
        }
        guard let attributes = try? attributesOfItem(atPath: path) else {
            return 0
        }
        if let type = attributes[.type] as? FileAttributeType, type == .typeDirectory {
            return folderSize(at: path)
        }
        return fileSize(at: path)
    }
    
    func fileSize(at filePath: String) -> UInt64 {
        if fileExists(atPath: filePath),
           let attriutes = try? attributesOfItem(atPath: filePath),
           let fileSize = attriutes[.size] as? UInt64 {
            return fileSize
        }
        return 0
    }
    
    func folderSize(at folderPath: String) -> UInt64 {
        guard fileExists(atPath: folderPath) else { return 0 }
        
        var folderSize: UInt64 = 0
        if let childFiles = try? subpathsOfDirectory(atPath: folderPath) {
            for path in childFiles {
                let itemPath = folderPath.appending(path)
                let fileSize = fileSize(at: itemPath)
                folderSize = folderSize + fileSize
            }
        }
        return folderSize
    }
}

func XSimAvailableDevicesInfo() -> [String: [JSON]] {
    let scriptPath = Bundle.main.path(forResource: "SimctlList", ofType: "sh")
    let scriptTask = Process()
    let outputPipe = Pipe()
    
    scriptTask.standardOutput = outputPipe
    
    scriptTask.launchPath = "/bin/sh"
    scriptTask.arguments = [scriptPath!]
    scriptTask.launch()
    
    let fileHandle = outputPipe.fileHandleForReading
    let data = fileHandle.readDataToEndOfFile()
    
    guard let json = try? JSON(data: data) else { return [:] }
    let devices = json["devices"].dictionaryValue.compactMapValues { json in
        return json.arrayValue
    }
    return devices
}

func XSimAvailableDeviceList() -> [Simulator] {
    // /Users/XuYingjie/Library/Developer/CoreSimulator/Devices/device_set.plist
    let devicesPath = NSHomeDirectory().appending("/Library/Developer/CoreSimulator/Devices/")
    let devicesInfos = XSimAvailableDevicesInfo()
    var deviceList = [JSON]()
    for (systemVersion, devices) in devicesInfos {
        let version = systemVersion.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
        for device in devices {
            var newDevice = device
            newDevice["SVersion"].string = version
            let path = devicesPath.appending(device["udid"].stringValue)
            newDevice["Path"].string = path
            
            deviceList.append(newDevice)
        }
    }
    
    var simulators = [Simulator]()
    for device in deviceList {
        let model = device["name"].stringValue
        let name = device["name"].stringValue
        let systemVersion = device["SVersion"].stringValue
        let path = device["Path"].stringValue
        let status = SimulatorStatus(rawValue: device["state"].stringValue)!
        let deviceId = device["udid"].stringValue
        
        let simulator = Simulator(model: model, name: name, systemVersion: systemVersion, path: path, deviceId: deviceId, status: status)
        simulators.append(simulator)
    }
    
    print("---\(simulators)")
    
    return simulators
}


class WarpObject: NSObject {
    var object: Any?
}

struct SimulatorUserApplication {
    let identifier: String
    let bundlePath: String
    let sandboxPath: String
    let displayName: String
    //let bundleSize: UInt64
    let simulator: Simulator
}

enum SimulatorStatus : String{
    case Booted = "Booted"
    case Shutdown = "Shutdown"
}

struct Simulator: Identifiable, Hashable {
    var id: String {
        return deviceId
    }
    
    static let all: [Simulator] = XSimAvailableDeviceList()
    
    var model: String
    let name: String
    let systemVersion: String
    let path: String
    let deviceId: String
    let status: SimulatorStatus
    
    func userApplicationPath() -> String {
        let appPath = path.appending("/data/Containers/Bundle/Application")
        return appPath
    }
    
    func userApplications() throws -> [SimulatorUserApplication] {
        let applicationPath = userApplicationPath()
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: applicationPath) else {
            return []
        }
        
        let applicationPaths = try? fileManager.contentsOfDirectory(atPath: applicationPath)
        
        var applications: [SimulatorUserApplication] = []
        for appItemPath in applicationPaths! {
            if appItemPath == ".DS_Store" {
                continue
            }
            let appPath = applicationPath.appending("/\(appItemPath)")
            let itemAttributes = try fileManager.attributesOfItem(atPath: appPath)
            //let itemFileSystemAttributes = try? fileManager.attributesOfFileSystemForPath(itemPath)
            
            if let type = itemAttributes[.type] as? FileAttributeType, type == .typeDirectory {
                var identifier: String = ""
                var bundlePath: String = ""
                var displayName: String = ""
                //var bundleSize: UInt64 = 0
                var sandboxPath: String = ""
                
                //fileManager.folderSize(at: appPath)
                
                let metadataPlistPath = appPath.appending("/.com.apple.mobile_container_manager.metadata.plist")
                let metadataPlist = NSDictionary(contentsOfFile: metadataPlistPath)
                identifier = (metadataPlist?.object(forKey: "MCMMetadataIdentifier"))! as! String
                
                func searchBundlePath(appPath: String) -> String {
                    let contents = try? fileManager.contentsOfDirectory(atPath: appPath)
                    for item in contents! {
                        if item.hasSuffix(".app") {
                            let path = appPath.appending("/\(item)")
                            return path
                        }
                    }
                    return ""
                }
                
                bundlePath = searchBundlePath(appPath: appPath)
                
                displayName = fileManager.displayName(atPath: bundlePath)
                
                func searchApplicationSandboxFor(identifier: String) throws -> String {
                    let sandboxsPath = applicationPath.replacingOccurrences(of: "/Bundle/Application", with: "").appending("/Data/Application")
                    let sandboxPaths = try? fileManager.contentsOfDirectory(atPath: sandboxsPath)
                    for itemPath in sandboxPaths! {
                        if itemPath == ".DS_Store" {
                            continue
                        }
                        let sandboxPath = sandboxsPath.appending("/\(itemPath)")
                        let attributes = try fileManager.attributesOfItem(atPath: sandboxPath)
                        if let type = attributes[.type] as? FileAttributeType, type == .typeDirectory {
                            let metadataPath = sandboxPath.appending("/.com.apple.mobile_container_manager.metadata.plist")
                            if fileManager.fileExists(atPath: metadataPath) == false {
                                continue
                            }
                            let metadata = NSDictionary(contentsOfFile: metadataPath)!
                            let appIdentifier = (metadata.object(forKey: "MCMMetadataIdentifier"))! as! String
                            if appIdentifier == identifier {
                                return sandboxPath
                            }
                        }
                    }
                    return ""
                }
                sandboxPath = try searchApplicationSandboxFor(identifier: identifier)
                
                let application = SimulatorUserApplication(identifier: identifier, bundlePath: bundlePath, sandboxPath: sandboxPath, displayName: displayName, simulator: self)
                applications.append(application)
            }
        }
        return applications
    }
}
