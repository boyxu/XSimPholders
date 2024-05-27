//
//  DeviceViewModel.swift
//  XSimPholders
//
//  Created by XuYingjie on 2024/5/27.
//

import Combine
import Foundation


class DeviceViewModel: ObservableObject {
    
    @Published private(set) var devices: [Device]
    
    let service: XSimDataService
    private var subscriptions = Set<AnyCancellable>()
    
    init(devices: [Device] = [], service: XSimDataService = .init()) {
        self.devices = devices
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
        self.devices = devices
    }
}




