//
//  BLEDriver.m
//  MixedDemo
//
//  Created by 曾长欢 on 2025/11/20.
//

#import "BLEDriver.h"
/**
 “千万不能在 .h 头文件里 import -Swift.h！ 这会造成循环引用（Circular Dependency）。
 因为 Bridge-Header 让 Swift 引用了 OC 的 .h。

 如果 OC 的 .h 又引用了 Swift 生成的 header。

 两者就会互相死锁，导致编译失败。
 */

#import "MixedDemo-Swift.h"
// 1. 遵守 CBCentralManagerDelegate 协议
@interface BLEDriver () <CBCentralManagerDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;

@end

@implementation BLEDriver
- (instancetype)initWithDeviceName:(NSString *)name {
    self = [super init];
    if (self) {
        _deviceName = name;
                // 初始化蓝牙中心管理对象
                // queue: nil 代表在主线程回调，实际开发建议放后台线程
                _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}
- (void)startScan {
    // 检查蓝牙是否开启
    if (self.centralManager.state == CBManagerStatePoweredOn) {
        NSLog(@"[OC底层] 蓝牙状态正常，开始扫描...");
        // ServiceUUIDs 传 nil 代表扫描所有设备
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    } else {
        NSLog(@"[OC底层] 蓝牙未就绪，当前状态: %ld", (long)self.centralManager.state);
    }
}

// 【新增】停止扫描实现
- (void)stopScan {
    // 实际调用 CoreBluetooth 的方法
    if (self.centralManager.isScanning) {
        [self.centralManager stopScan];
        NSLog(@"[OC底层驱动] 停止扫描...");
    }
}

// 【新增】连接实现
- (void)connectToDeviceWithName:(NSString *)deviceName {
    NSLog(@"[OC底层驱动] 尝试连接设备: %@", deviceName);
    
    // ⚠️ 实际应用中，你需要先找到对应的 CBPeripheral 实例，这里简化为打印
    
    // 假设我们找到了设备，并开始连接：
    // [self.centralManager connectPeripheral:self.connectingPeripheral options:nil];
    
    [self stopScan];
    
    // 模拟 1.5 秒连接耗时，然后假装连接成功
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 核心逻辑：通知连接成功
        if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToDevice:)]) {
            [self.delegate didConnectToDevice:deviceName];
        }
    });
}
- (void)sendCommand:(NSString *)hexCommand toDevice:(DeviceType)type {
    NSString *typeString = (type == DeviceTypeLight) ? @"补光灯" : @"云台";
    NSLog(@"[OC底层] 正在向 [%@] 发送指令: %@", typeString, hexCommand);
    
    // --- 模拟硬件延时回复 ---
    // 使用 GCD 模拟 2 秒后收到硬件数据
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSLog(@"[OC底层] ⚡️ 收到硬件响应数据！准备通知 Swift...");
        
        // 1. 调用 Swift 单例
        // 注意：Swift 的 UIHelper.shared 在这里变成了 [UIHelper shared]
        UIHelper *helper = [UIHelper shared];
        
        // 2. 调用 Swift 方法
        // 注意：showHardwareMessage(_ message:) 变成了 showHardwareMessage:
        [helper showHardwareMessage:@"亮度调节完毕 (from OC)"];
        
    });
}

#pragma mark - CBCentralManagerDelegate (连接状态处理)

// 【新增/替换】连接成功的回调（现在我们将使用这个方法进行服务发现）
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"[OC底层] 🟢 设备连接成功: %@", peripheral.name);
    
    // ⚠️ 实际步骤：
    // 1. 将 peripheral 设置为 BLEDriver 的一个属性，以便后续操作
    // 2. 开始发现服务：[peripheral discoverServices:nil];
    
    // 3. 通过 Delegate 通知 Swift 层
    if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToDevice:)]) {
        [self.delegate didConnectToDevice:peripheral.name];
    }
}

// 【新增】连接失败的回调
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"[OC底层] 🔴 设备连接失败: %@, 错误: %@", peripheral.name, error);
    
    // 通知 Swift 层连接失败
    if (self.delegate && [self.delegate respondsToSelector:@selector(didDisconnectOrFailToConnect:)]) {
        [self.delegate didDisconnectOrFailToConnect:peripheral.name];
    }
}

// 【新增】断开连接的回调
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"[OC底层] 🟡 设备已断开连接: %@", peripheral.name);

    // 通知 Swift 层断开连接
    if (self.delegate && [self.delegate respondsToSelector:@selector(didDisconnectOrFailToConnect:)]) {
        [self.delegate didDisconnectOrFailToConnect:peripheral.name];
    }
}

// 必须实现的协议方法：状态改变回调
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        NSLog(@"[OC底层] 蓝牙已开启");
    } else {
        NSLog(@"[OC底层] 蓝牙不可用");
    }
}

// 发现设备的回调
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    // 过滤掉没有名字的设备 (为了演示好看点)
    NSString *foundName = peripheral.name;
    if (!foundName) {
        foundName = @"未知设备 (No Name)";
    }
    
    // 2. 通过 Delegate 通知 Swift
    if (self.delegate && [self.delegate respondsToSelector:@selector(didDiscoverDeviceWithName:rssi:)]) {
        [self.delegate didDiscoverDeviceWithName:foundName rssi:RSSI];
    }
}
@end
