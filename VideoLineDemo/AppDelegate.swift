//
//  AppDelegate.swift
//  VideoLineDemo
//
//  Created by 王炜 on 2017/2/24.
//  Copyright © 2017年 Willie. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: PickingViewController())
        window?.makeKeyAndVisible()
        
        return true
    }
}

