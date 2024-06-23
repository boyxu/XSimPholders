//
//  XSimDataService.swift
//  XSimPholders
//
//  Created by XuYingjie on 2024/5/27.
//

import Combine
import Foundation
import SwiftyJSON
import AppKit

class XSimDataService {
    
    private static let devicesPath = NSHomeDirectory().appending("/Library/Developer/CoreSimulator/Devices/")
    
    let deviceListSubject = CurrentValueSubject<[OSDevices], Never>([])
    var deviceList: [OSDevices] { deviceListSubject.value }
    
    deinit {
        deviceListSubject.send(completion: .finished)
    }
    
    func openApplicationSandbox(path: String) {
        print("Open Path: \(path)")
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
        
//        guard let finderUrl = URL(string: "com.apple.Finder") else { return }
//        let config = NSWorkspace.OpenConfiguration()
//        config.activates = true
//        NSWorkspace.shared.open([url], withApplicationAt: finderUrl, configuration: config)
    }
    
    func runDeviceListTask() {
        let scriptPath = Bundle.main.path(forResource: "SimctlList", ofType: "sh")
        let scriptTask = Process()
        let outputPipe = Pipe()
        
        scriptTask.standardOutput = outputPipe
        
        scriptTask.launchPath = "/bin/sh"
        scriptTask.arguments = [scriptPath!]
        scriptTask.launch()
        
        let fileHandle = outputPipe.fileHandleForReading
        let data = fileHandle.readDataToEndOfFile()
        
        guard let json = try? JSON(data: data) else { return }
        let devicesJson = json["devices"].dictionaryValue
            .compactMapValues({ $0.arrayValue.count > 0 ? $0 : nil })
        onReceive(devicesJson: devicesJson)
    }
    
    private func onReceive(devicesJson: [String: JSON]) {
        
        var allDevices: [OSDevices] = []
        for (key, jsonArray) in devicesJson {
            let osVersion = key.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
            var devices: [Device] = []
            for device in jsonArray.arrayValue {
                let name = device["name"].stringValue
                let udid = device["udid"].stringValue
                let state = device["state"].stringValue
                let path = Self.devicesPath.appending(udid)
                let apps = applications(for: path)
                let device = Device(osVersion: osVersion, name: name, udid: udid, path: path, state: state, applications: apps)
                devices.append(device)
            }
            let osDevices = OSDevices(osVersion: osVersion, devices: devices)
            allDevices.append(osDevices)
        }
        deviceListSubject.send(allDevices)
    }
    
    private func applicationRootPath(for devicePath: String) -> String {
        let appPath = devicePath.appending("/data/Containers/Bundle/Application")
        return appPath
    }
    
    private func findAppBundlePath(for appFullPath: String) -> String? {
        let contents = try? FileManager.default.contentsOfDirectory(atPath: appFullPath)
        for item in contents! {
            if item.hasSuffix(".app") {
                let path = appFullPath.appending("/\(item)")
                return path
            }
        }
        return nil
    }
    
    private func findSandboxPath(for metadataIdentifier: String, applicationRootPath: String) -> String? {
        let sandboxRootPath = applicationRootPath.replacingOccurrences(of: "/Bundle/Application", with: "/Data/Application")
        
        guard let itemNames = try? FileManager.default.contentsOfDirectory(atPath: sandboxRootPath) else { return nil }
        for itemName in itemNames {
            if itemName == ".DS_Store" { continue }
            let sandboxPath = sandboxRootPath.appending("/\(itemName)")
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: sandboxPath),
                  let type = attributes[.type] as? FileAttributeType,
                  type == .typeDirectory else { continue }
            
            let metadataPath = sandboxPath.appending("/.com.apple.mobile_container_manager.metadata.plist")
            guard FileManager.default.fileExists(atPath: metadataPath) else { continue }
            
            guard let metadataPlist = NSDictionary(contentsOfFile: metadataPath),
                  let appIdentifier = metadataPlist["MCMMetadataIdentifier"] as? String else {
                continue
            }
            guard appIdentifier == metadataIdentifier else { continue }
            
            return sandboxPath
        }
        return nil
    }
    
    private func applications(for devicePath: String) -> [Application] {
        let applicationRootPath = applicationRootPath(for: devicePath)
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: applicationRootPath) else { return [] }
        guard let itemNames = try? fileManager.contentsOfDirectory(atPath: applicationRootPath) else { return [] }
        
        
        var applications: [Application] = []
        for itemName in itemNames {
            if itemName == ".DS_Store" { continue }
            let appFullPath = applicationRootPath.appending("/\(itemName)")
            
            guard let appItemAttributes = try? fileManager.attributesOfItem(atPath: appFullPath),
                  let type = appItemAttributes[.type] as? FileAttributeType,
                  type == .typeDirectory else { continue }
            
            let metadataPlistPath = appFullPath.appending("/.com.apple.mobile_container_manager.metadata.plist")
            guard let metadataPlist = NSDictionary(contentsOfFile: metadataPlistPath),
                  let identifier = metadataPlist["MCMMetadataIdentifier"] as? String else {
                continue
            }
            
            guard let bundlePath = findAppBundlePath(for: appFullPath) else { continue }
            
            guard let sandboxPath = findSandboxPath(for: identifier, applicationRootPath: applicationRootPath) else { continue }
            
            let displayName = fileManager.displayName(atPath: bundlePath)
            
            let app = Application(identifier: identifier, displayName: displayName, bundlePath: bundlePath, sandboxPath: sandboxPath)
            applications.append(app)
        }
        return applications
    }
}
