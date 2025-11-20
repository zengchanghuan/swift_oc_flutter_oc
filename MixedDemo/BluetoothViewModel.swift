//
//  BluetoothViewModel.swift
//  MixedDemo
//
//  Created by 曾长欢 on 2025/11/20.
//

import Foundation
import Combine // 引入 Combine
import UIKit // 导入 UIKit 是因为 BLEDriver 是通过桥接头文件导入的


// 定义一个连接状态枚举，便于在 Swift UI 中处理不同状态
enum ConnectionState {
    case disconnected     // 初始/断开
    case scanning         // 正在扫描中
    case connecting(String) // 正在连接中 (携带设备名)
    case connected(String)  // 已连接 (携带设备名)
    case failed(String)     // 连接失败 (携带设备名)
}

final class BluetoothViewModel: NSObject, ObservableObject {
    
    // 1. @Published 核心数据：设备列表
    @Published var deviceList: [String] = []
    
    // 2. @Published 核心数据：连接状态
    @Published var connectionStatus: ConnectionState = .disconnected
    
    // ... 其他属性和 init 保持不变 ...
    private var driver: BLEDriver?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        self.driver = BLEDriver(deviceName: "ViewModel_Managed")
        self.driver?.delegate = self
    }
    
    // MARK: - 供 View 调用的业务方法
    
    func startScan() {
        print("[ViewModel] 接收到 View 指令：开始扫描")
        // 更新状态为 Scanning
        self.connectionStatus = .scanning
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.driver?.startScan()
        }
    }
    
    func connect(toDeviceName name: String) {
        print("[ViewModel] 接收到 View 指令：连接设备 \(name)")
        
        // 更新状态为 Connecting，并传入设备名
        self.connectionStatus = .connecting(name)
        
        self.driver?.connectDevice(name: name)
    }
}


// MARK: - BLEDriverDelegate (ViewModel 接收 OC 的回调)

extension BluetoothViewModel: BLEDriverDelegate {
    
    // 接收新设备回调 (保持不变)
    func didDiscoverDevice(withName name: String, rssi: NSNumber) {
        if !deviceList.contains(where: { $0.contains(name) }) {
            let text = "\(name) [信号: \(rssi)]"
            DispatchQueue.main.async {
                self.deviceList.append(text)
            }
        }
    }
    
    // 【最终修正 1】接收连接成功回调：使用 Swift 规范名
    func didConnect(toDevice name: String) {
        print("✅ [ViewModel] 设备 \(name) 连接成功。")
        self.connectionStatus = .connected(name)
        
        self.driver?.stopScan()
        self.deviceList.removeAll()
    }
    
    // 【最终修正 2】接收连接失败/断开回调：使用 Swift 规范名
    func didDisconnectOrFail(toConnect name: String) {
        print("🔴 [ViewModel] 设备 \(name) 断开或连接失败。")
        self.connectionStatus = .failed(name)
    }
}
