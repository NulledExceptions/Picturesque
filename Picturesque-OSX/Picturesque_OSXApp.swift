//
//  Picturesque_OSXApp.swift
//  Picturesque-OSX
//
//  MINIMAL VERSION - Works with your existing ContentView
//

import SwiftUI

@main
struct Picturesque_OSXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
