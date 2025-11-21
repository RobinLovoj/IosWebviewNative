//
//  NetworkMonitor.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    @Published var isOnline = false
    @Published var connectionType: String = "Unknown"
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = "WiFi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = "Cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = "Ethernet"
                } else {
                    self?.connectionType = "Unknown"
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    func checkInternetAvailability() -> Bool {
        return isOnline
    }
}




