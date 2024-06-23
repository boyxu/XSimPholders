//
//  DeviceViewModel.swift
//  XSimPholders
//
//  Created by XuYingjie on 2024/5/27.
//

import Combine
import Foundation


class DeviceViewModel: ObservableObject {
    
    @Published private(set) var osDevices: [OSDevices]
    
    let service: XSimDataService
    private var subscriptions = Set<AnyCancellable>()
    
    init(osDevices: [OSDevices] = [], service: XSimDataService = .init()) {
        self.osDevices = osDevices
        self.service = service
    }
    
    func subscribeToService() {
        service.deviceListSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateView()
            }
            .store(in: &subscriptions)
    }
    
    func updateView() {
        print("updateView...")
        let devices = service.deviceList
        self.osDevices = devices
    }
    
}




