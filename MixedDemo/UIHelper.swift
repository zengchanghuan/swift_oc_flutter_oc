//
//  UIHelper.swift
//  MixedDemo
//
//  Created by 曾长欢 on 2025/11/20.
//

import UIKit


// @objcMembers: 这个关键字让类里所有属性和方法都自动暴露给 OC
@objcMembers
class UIHelper: NSObject {
    
    // 单例模式 (方便 OC 直接通过 shared 拿到实例，不用传参数)
    static let shared = UIHelper()
    
    // 这是一个供 OC 调用的方法
    func showHardwareMessage(_ message: String) {
        print("✅ [Swift UI层] 收到回调: \(message)")
        
        // 实际开发中，这里会写弹窗代码
        // 为了防止线程问题，强制在主线程执行
        DispatchQueue.main.async {
            // 这里简单打印，或者你可以写个 UIAlertController
            print("   >>> 正在刷新界面弹窗...")
        }
    }
}
