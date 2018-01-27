//
//  AppDelegate.swift
//  SilicaSample
//
//  Created by ilo on 26/06/2017.
//  Copyright © 2017 SiO2. All rights reserved.
//

import Cocoa
import Silica


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!


  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application
    
    DispatchQueue.main.async {
      if !AXIsProcessTrusted() {
        print("needs permission!!")
      }
      if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").last {
        let siApp = SIApplication(runningApplication: finder)!
        siApp.observeNotification(kAXWindowMovedNotification as CFString, with: siApp, handler: { (element) in
          print("\(element) received notification.")
        })
        print("registered for \(siApp)")
      }

    }
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }


}

