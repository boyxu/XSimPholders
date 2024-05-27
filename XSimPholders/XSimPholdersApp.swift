//
//  XSimPholdersApp.swift
//  XSimPholders
//
//  Created by XuYingjie on 2024/5/23.
//

import SwiftUI
import MenuBarExtraAccess

@main
struct XSimPholdersApp: App {
    
    var deviceViewModel: DeviceViewModel!
    var dataService = XSimDataService()
    
    init() {
        deviceViewModel = DeviceViewModel(service: dataService)
        dataService.runDeviceListTask()
        deviceViewModel.subscribeToService()
    }
    
    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: deviceViewModel)
        } label: {
            VStack {
                Image("StatusBarIcon")
            }
        }
        .menuBarExtraStyle(.menu)
        
    }
    
}

