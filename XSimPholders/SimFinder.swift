//
//  SimFinder.swift
//  XSimPholders
//
//  Created by 徐英杰 on 4/30/16.
//  Copyright © 2016 Yingjie Xu. All rights reserved.
//

import Cocoa

//CalculateSize
extension NSFileManager {
    func fileSizeForPath(path: String) -> UInt64 {
        if !fileExistsAtPath(path) {
            return 0
        }
        let attributes = try? self.attributesOfItemAtPath(path) as NSDictionary
        guard let fileAttributes = attributes else {
            return 0
        }
        if fileAttributes.fileType() == NSFileTypeDirectory{
            return folderSizeAtPath(path)
        }
        return fileSizeAtPath(path)
    }
    
    func fileSizeAtPath(filePath: String) -> UInt64 {
        if fileExistsAtPath(filePath) {
            let attributes = try? attributesOfItemAtPath(filePath) as NSDictionary
            return (attributes?.fileSize())!
        }
        return 0
    }
    
    func folderSizeAtPath(folderPath: String) -> UInt64 {
        if !fileExistsAtPath(folderPath) {
            return 0
        }
        let childFiles = try? subpathsOfDirectoryAtPath(folderPath)
        var folderSize: UInt64 = 0
        if let files = childFiles {
            for path in files {
                let itemPath = folderPath.stringByAppendingString(path)
                let fileSize = fileSizeAtPath(itemPath)
                folderSize = folderSize + fileSize
            }
        }
        return folderSize
    }
    
}

func availableDevicesInfo() -> Dictionary<String, Array<Dictionary<String, String>>> {
    //
    let scriptPath = NSBundle.mainBundle().pathForResource("SimctlList", ofType: "sh")
    
    let scriptTask = NSTask()
    
    let outputPipe = NSPipe()
    scriptTask.standardOutput = outputPipe
    
    scriptTask.launchPath = "/bin/sh"
    scriptTask.arguments = [scriptPath!]
    scriptTask.launch()
    
    let fileHandle = outputPipe.fileHandleForReading
    let data = fileHandle.readDataToEndOfFile()
    let simDeviceType = String(data: data, encoding: NSUTF8StringEncoding)
    
    let simDevices = simDeviceType?.componentsSeparatedByString("\n").filter({ (line) -> Bool in
        var isRemove = true
        if line.localizedCaseInsensitiveContainsString("unavailable") {
            isRemove = false
        }
        if line.hasPrefix("== ") && line.hasSuffix(" ==") {
            isRemove = false
        }
        if line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0 {
            isRemove = false
        }
        
        return isRemove
    })
    
    var devices = [String : [[String:String]]]()
    var systemVersion: String = ""
    for (_, text) in (simDevices?.enumerate())! {
        if text.hasPrefix("-- ") && text.hasSuffix(" --") {
            let startIndex = text.startIndex.advancedBy(3)
            let endIndex = text.endIndex.advancedBy(-3)
            let range = Range<String.Index>(startIndex ..< endIndex)
            systemVersion = text.substringWithRange(range)
        }else {
            let value = text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            var infos = devices[systemVersion]
            if infos == nil {
                infos = []
                devices[systemVersion] = infos
            }
            let testStrings = value.componentsSeparatedByString(" (")
            let deviceInfo = ["Model": testStrings.first!,
                              "DeviceId": testStrings[1].stringByReplacingOccurrencesOfString(")", withString: ""),
                              "Status": testStrings[2].stringByReplacingOccurrencesOfString(")", withString: ""),
                              ]
            
            infos?.append(deviceInfo)
            devices.updateValue(infos!, forKey: systemVersion)
        }
    }
    return devices
}

func availableDeviceList() -> Array<Simulator> {
    // /Users/XuYingjie/Library/Developer/CoreSimulator/Devices/device_set.plist
    let devicesPath = NSHomeDirectory().stringByAppendingString("/Library/Developer/CoreSimulator/Devices/")
    let devicesInfos = availableDevicesInfo()
    var deviceList = [[String: String]]()
    for (systemVersion, devices) in devicesInfos {
        for device in devices {
            var newDevice = device
            newDevice["SVersion"] = systemVersion
            let path = devicesPath.stringByAppendingString(device["DeviceId"]!)
            newDevice["Path"] = path
            
            let devicePlistFile = path.stringByAppendingString("/device.plist")
            let devicePlist = NSDictionary(contentsOfFile: devicePlistFile)
            newDevice["Name"] = devicePlist?.objectForKey("name") as? String
            
            deviceList.append(newDevice)
        }
    }
    
    var simulators = [Simulator]()
    for device in deviceList {
        let model = device["Model"]!
        let name = device["Name"]!
        let systemVersion = device["SVersion"]!
        let path = device["Path"]!
        let status: SimulatorStatus = SimulatorStatus(rawValue: device["Status"]!)!
        let deviceId = device["DeviceId"]!
        
        let simulator = Simulator(model: model, name: name, systemVersion: systemVersion, path: path, deviceId: deviceId, status: status)
        simulators.append(simulator)
    }
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

struct Simulator {
    static let all: [Simulator] = availableDeviceList()
    
    let model: String
    let name: String
    let systemVersion: String
    let path: String
    let deviceId: String
    let status: SimulatorStatus
    
    func userApplicationPath() -> String {
        let appPath = path.stringByAppendingString("/data/Containers/Bundle/Application")
        return appPath
    }
    
    func userApplications() -> [SimulatorUserApplication] {
        let applicationPath = userApplicationPath()
        let fileManager = NSFileManager.defaultManager()
        
        guard fileManager.fileExistsAtPath(applicationPath) else {
            return []
        }
        
        let applicationPaths = try? fileManager.contentsOfDirectoryAtPath(applicationPath)
        
        var applications: [SimulatorUserApplication] = []
        for appItemPath in applicationPaths! {
            if appItemPath == ".DS_Store" {
                continue
            }
            let appPath = applicationPath.stringByAppendingString("/\(appItemPath)")
            let itemAttributes = try? fileManager.attributesOfItemAtPath(appPath) as NSDictionary
            //let itemFileSystemAttributes = try? fileManager.attributesOfFileSystemForPath(itemPath)
            
            if itemAttributes!.fileType() == NSFileTypeDirectory {
                var identifier: String = ""
                var bundlePath: String = ""
                var displayName: String = ""
                var bundleSize: UInt64 = 0
                var sandboxPath: String = ""
                
                fileManager.folderSizeAtPath(appPath)
                
                let metadataPlistPath = appPath.stringByAppendingString("/.com.apple.mobile_container_manager.metadata.plist")
                let metadataPlist = NSDictionary(contentsOfFile: metadataPlistPath)
                identifier = (metadataPlist?.objectForKey("MCMMetadataIdentifier"))! as! String
                
                func searchBundlePath(appPath: String) -> String {
                    let contents = try? fileManager.contentsOfDirectoryAtPath(appPath)
                    for item in contents! {
                        if item.hasSuffix(".app") {
                            let path = appPath.stringByAppendingString("/\(item)")
                            return path
                        }
                    }
                    return ""
                }
                bundlePath = searchBundlePath(appPath)
                
                displayName = fileManager.displayNameAtPath(bundlePath)
                
                func searchApplicationSandboxFor(identifier identifier: String) -> String {
                    let sandboxsPath = applicationPath.stringByReplacingOccurrencesOfString("/Bundle/Application", withString: "").stringByAppendingString("/Data/Application")
                    let sandboxPaths = try? fileManager.contentsOfDirectoryAtPath(sandboxsPath)
                    for itemPath in sandboxPaths! {
                        if itemPath == ".DS_Store" {
                            continue
                        }
                        let sandboxPath = sandboxsPath.stringByAppendingString("/\(itemPath)")
                        let attributes = try? fileManager.attributesOfItemAtPath(sandboxPath) as NSDictionary
                        if attributes!.fileType() == NSFileTypeDirectory {
                            let metadataPath = sandboxPath.stringByAppendingString("/.com.apple.mobile_container_manager.metadata.plist")
                            if fileManager.fileExistsAtPath(metadataPath) == false {
                                continue
                            }
                            let metadata = NSDictionary(contentsOfFile: metadataPath)!
                            let appIdentifier = (metadata.objectForKey("MCMMetadataIdentifier"))! as! String
                            if appIdentifier == identifier {
                                return sandboxPath
                            }
                        }
                    }
                    return ""
                }
                sandboxPath = searchApplicationSandboxFor(identifier: identifier)
                
                let application = SimulatorUserApplication(identifier: identifier, bundlePath: bundlePath, sandboxPath: sandboxPath, displayName: displayName, simulator: self)
                applications.append(application)
            }
        }
        return applications
    }
    
    
    
    
    
}
