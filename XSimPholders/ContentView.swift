//
//  ContentView.swift
//  XSimPholders
//
//  Created by XuYingjie on 2024/5/23.
//

import SwiftUI
import Combine

struct ContentView: View {
    
    @GestureState var isPressed = false
    @ObservedObject var viewModel: DeviceViewModel
    
    var body: some View {
        VStack {
            ForEach(viewModel.osDevices) { osDevices in
                ForEach(osDevices.devices) { device in
                    Menu("\(device.osVersion) \(device.name)") {
                        ForEach(device.applications) { app in
                            Button {
                                viewModel.service.openApplicationSandbox(path: app.sandboxPath)
                            } label: {
                                Text(app.displayName)
                            }
                        }
                    }
                }
                Divider()
            }
            
            HStack {
                Button("Refresh Devices") {
                    print("Refresh Devices")
                    viewModel.service.runDeviceListTask()
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding()
    }
}


#Preview {
    ContentView(viewModel: DeviceViewModel())
}
