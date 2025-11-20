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
    
    private lazy var lightSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        // 添加事件监听
        sw.addTarget(self, action: #selector(lightSwitchChanged), for: .valueChanged)
        return sw
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
    // ViewController.swift

    // ViewController.swift

    private func updateUI(for status: ConnectionState) {
        // 确保 navigationController 存在
        guard let navigationController = self.navigationController else { return }

        switch status {
        case .disconnected:
            self.title = "蓝牙设备 (未连接)"
            // 修正 1 & 2: 使用 navigationController?.navigationBar 和 .systemBackground
            navigationController.navigationBar.barTintColor = .systemBackground
            
        case .scanning:
            self.title = "正在扫描..."
            navigationController.navigationBar.barTintColor = .systemYellow
            
        case .connecting(let name):
            self.title = "连接中: \(name)"
            navigationController.navigationBar.barTintColor = .systemOrange
            
        case .connected(let name):
            self.title = "已连接: \(name)"
            navigationController.navigationBar.barTintColor = .systemGreen

        case .servicesReady(let name):
            self.title = "✅ 可通信: \(name)"
            navigationController.navigationBar.barTintColor = .systemBlue
            
        case .failed(let name):
            self.title = "连接失败/断开: \(name)"
            // 修正 1 & 2: 使用 navigationController.navigationBar 和 .systemRed
            navigationController.navigationBar.barTintColor = .systemRed
        }
    }
    
    // ViewController.swift

    @objc func lightSwitchChanged(_ sender: UISwitch) {
        
        // 核心修正：只有当连接状态为 .servicesReady 时，才允许发送指令
        guard case .servicesReady = viewModel.connectionStatus else {
            
            print("⚠️ 无法发送指令，BLE 尚未准备就绪 (不在 servicesReady 状态)")
            
            // 1. 给用户一个提示（可选）
            let alert = UIAlertController(title: "操作失败",
                                          message: "设备服务尚未发现，请稍候再试。",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            
            // 2. 关键：将开关状态回拨，防止 UI 状态和实际硬件状态不一致
            sender.isOn = !sender.isOn
            
            return
        }
        
        // 只有状态检查通过，才调用 ViewModel 的控制方法
        viewModel.toggleLight(isOn: sender.isOn)
    }
    func setupUI() {
        // ⚠️ 坑位3：必须先添加到视图层级，才能设置约束
        view.addSubview(tableView)
        view.addSubview(lightSwitch) // 【新增】添加开关
        
        // 激活约束 (让 TableView 撑满全屏)
        NSLayoutConstraint.activate([
            // TableView 顶部改为 lightSwitch 底部
            tableView.topAnchor.constraint(equalTo: lightSwitch.bottomAnchor, constant: 10),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 【新增】开关的布局
            lightSwitch.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            lightSwitch.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
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
    
}
