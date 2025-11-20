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
    case servicesReady(String) // ⚠️ 确保这一行存在！
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
    
    // 假设 1 代表 ON (开灯), 0 代表 OFF (关灯)
    func toggleLight(isOn: Bool) {
        
        // 1. 准备要发送的数据 (单字节)
        var value: UInt8 = isOn ? 1 : 0
        let data = Data(bytes: &value, count: 1)
        
        // 2. 调用 BLEDriver 的写入方法
        // ⚠️ 注意 Swift 签名转换：writeValue:forCharacteristicUUID: 转换为 writeValue(_:forCharacteristicUUID:)
        self.driver?.writeValue(data, forCharacteristicUUID: "1001")
        
        print("[ViewModel] 💡 发起控制指令：\(isOn ? "开灯" : "关灯")")
    }
}


// MARK: - BLEDriverDelegate (ViewModel 接收 OC 的回调)

extension BluetoothViewModel: BLEDriverDelegate {
    
    // 1. 发现设备回调 (已确认的 Swift 签名)
    func didDiscoverDevice(withName name: String, rssi: NSNumber) {
        if !deviceList.contains(where: { $0.contains(name) }) {
            let text = "\(name) [信号: \(rssi)]"
            DispatchQueue.main.async {
                self.deviceList.append(text)
            }
        }
    }
    
    // 2. 连接成功回调 (编译器提示的 Swift 规范名)
    func didConnect(toDevice name: String) {
        print("✅ [ViewModel] 设备 \(name) 连接成功。")
        self.connectionStatus = .connected(name)
        
        self.driver?.stopScan()
        self.deviceList.removeAll()
    }
    
    // 3. 连接失败/断开回调 (编译器提示的 Swift 规范名)
    func didDisconnectOrFail(toConnect name: String) {
        print("🔴 [ViewModel] 设备 \(name) 断开或连接失败。")
        self.connectionStatus = .failed(name)
    }
    
    // 4. 发现服务回调 (新方法，使用最符合规范的 Swift 签名)
    func didDiscoverServices(forDevice name: String) {
        print("✨ [ViewModel] 设备 \(name) 服务和特征已发现，可以开始读写数据了！")
        self.connectionStatus = .servicesReady(name)
    }
}
