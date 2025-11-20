//
//  ViewController.swift
//  MixedDemo
//
//  Created by 曾长欢 on 2025/11/20.
//

import UIKit
import Combine // 引入 Combine


class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // 核心修正 2：在 UIKit 中，使用私有 let 强引用 ViewModel，不使用 @ObservedObject
    private let viewModel = BluetoothViewModel()
    
    // 存储 Combine 订阅，防止内存泄漏
    private var cancellables = Set<AnyCancellable>()
    
    // 保持不变：UI 组件
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "CodeCell")
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        
        // 核心：设置数据绑定和启动扫描
        setupBinding()
        viewModel.startScan()
    }
        
    // MARK: - Combine 数据绑定

    func setupBinding() {
        // 1. 订阅设备列表变化 (保持不变)
        viewModel.$deviceList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        // 2. 【新增】订阅连接状态变化
        viewModel.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateUI(for: status)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - UI 状态更新方法
    // 【新增】一个私有方法来处理 UI 状态的展示

    private func updateUI(for status: ConnectionState) {
        switch status {
        case .disconnected:
            self.title = "蓝牙设备 (未连接)"
            self.navigationController?.navigationBar.barTintColor = .systemBackground // 默认颜色
            
        case .scanning:
            self.title = "正在扫描..."
            self.navigationController?.navigationBar.barTintColor = .systemYellow
            
        case .connecting(let name):
            self.title = "连接中: \(name)"
            self.navigationController?.navigationBar.barTintColor = .systemOrange
            
        case .connected(let name):
            self.title = "已连接: \(name)"
            self.navigationController?.navigationBar.barTintColor = .systemGreen
            
        case .failed(let name):
            self.title = "连接失败/断开: \(name)"
            self.navigationController?.navigationBar.barTintColor = .systemRed
            // 可以在这里显示一个 UIAlertController 提示用户
        }
    }

    // MARK: - UITableViewDelegate (列表交互)
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 从 ViewModel 获取数据
        let deviceText = viewModel.deviceList[indexPath.row]
        guard let deviceName = deviceText.split(separator: " ").first else { return }
        
        // 5. 只调用 ViewModel 的方法，保持解耦
        viewModel.connect(toDeviceName: String(deviceName))
    }
    
    // MARK: - UITableViewDataSource (从 ViewModel 读取数据)
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // 数据源直接是 ViewModel 的属性
        return viewModel.deviceList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CodeCell", for: indexPath)
        let deviceName = viewModel.deviceList[indexPath.row]
        
        var config = cell.defaultContentConfiguration()
        config.text = deviceName
        config.secondaryText = "点击连接"
        cell.contentConfiguration = config
        
        return cell
    }
    
    // ... setupUI() 保持不变 ...
    func setupUI() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
/*
class ViewController: UIViewController, BLEDriverDelegate, UITableViewDataSource {

    // -------------------------------------------------
    // 1. 定义 UI 组件 (使用 lazy var 懒加载是最佳实践)
    // -------------------------------------------------
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        
        // ⚠️ 坑位1：使用 AutoLayout 必须把这个设为 false
        tv.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置代理
        tv.dataSource = self
        tv.delegate = self
        
        // ⚠️ 坑位2：纯代码必须注册 Cell 类，否则崩溃
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "CodeCell")
        
        return tv
    }()
    
    // 业务相关属性
    var driver: BLEDriver?
    var deviceList: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置背景色 (方便调试)
        view.backgroundColor = .white
        
        // 2. 布局 UI
        setupUI()
        
        // 3. 启动蓝牙逻辑 (保持不变)
        startBluetoothLogic()
    }
    
    // -------------------------------------------------
    // 4. 布局代码 (Auto Layout)
    // -------------------------------------------------
    func setupUI() {
        // ⚠️ 坑位3：必须先添加到视图层级，才能设置约束
        view.addSubview(tableView)
        
        // 激活约束 (让 TableView 撑满全屏)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func startBluetoothLogic() {
        print("--- App 启动 (纯代码版) ---")
        self.driver = BLEDriver(deviceName: "iPhone_Pro_Code")
        self.driver?.delegate = self
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.driver?.startScan()
        }
    }
    
    // -------------------------------------------------
    // 5. 代理方法 (和之前基本一样)
    // -------------------------------------------------
    
    // BLEDriverDelegate
    func didDiscoverDevice(withName name: String, rssi: NSNumber) {
        if !deviceList.contains(name) {
            let text = "\(name) [信号: \(rssi)]"
            deviceList.append(text)
            print("📱 发现: \(text)")
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    // UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return deviceList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 注意：这里的 ID 必须和上面 register 时填的一样 "CodeCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: "CodeCell", for: indexPath)
        
        // 纯代码 Cell 设置内容
        // iOS 14+ 推荐用 contentConfiguration，但为了兼容旧代码，textLabel 也能用
        var config = cell.defaultContentConfiguration()
        config.text = deviceList[indexPath.row]
        config.secondaryText = "点击连接" // 加个副标题玩玩
        cell.contentConfiguration = config
        
        return cell
    }
}

// MARK: - UITableViewDelegate (列表交互)

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // 1. 立即取消选中状态，优化用户体验
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 2. 获取被点击的设备名称（从数据中提取）
        let deviceText = deviceList[indexPath.row]
        
        // 3. 解析设备名 (因为数据是 "名称 [信号: -XX]" 格式)
        // 使用 guard let 确保我们拿到了纯净的设备名
        guard let deviceName = deviceText.split(separator: " ").first else {
            print("解析设备名失败: \(deviceText)")
            return
        }
        let finalDeviceName = String(deviceName)
        
        print(">>> 用户点击了：\(finalDeviceName)，准备发起连接...")
        
        // 4. 调用 OC 驱动的发起连接方法
        // 注意：OC 的方法名 connectToDeviceWithName 自动转为了 Swift 风格的 connect(toDeviceWithName:)
        driver?.connectDevice(name: finalDeviceName)
        // 【思考题】实际项目中，你可能需要在这里更新 UI：
        // 比如把这一行 Cell 的颜色变灰，并显示“连接中...”
    }
}
*/
