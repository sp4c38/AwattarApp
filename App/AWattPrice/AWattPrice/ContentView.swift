//
//  TabBar.swift
//  AWattPrice
//
//  Created by Léon Becker on 28.11.20.
//

import SwiftUI

/// Start of the application.
struct ContentView: View {
    @Environment(\.networkManager) var networkManager
    @Environment(\.notificationAccess) var notificationAccess
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    @EnvironmentObject var currentSetting: CurrentSetting

    @ObservedObject var tabBarItems = TBItems()
    
    @State var initialAppearFinished: Bool? = false
    
    var body: some View {
        VStack {
            if currentSetting.entity != nil {
                VStack(spacing: 0) {
                    if currentSetting.entity!.splashScreensFinished == true {
                        ZStack {
                            SettingsPageView()
                                .opacity(tabBarItems.selectedItemIndex == 0 ? 1 : 0)
                                .environmentObject(tabBarItems)
                            
                            HomeView()
                                .opacity(tabBarItems.selectedItemIndex == 1 ? 1 : 0)
                                    
                            CheapestTimeView()
                                .opacity(tabBarItems.selectedItemIndex == 2 ? 1 : 0)
                        }
                        .onAppear {
                            managePushNotificationsOnAppAppear(notificationAccessRepresentable: notificationAccess, registerForRemoteNotifications: true)
                            initialAppearFinished = nil
                        }
                        .onChange(of: scenePhase) { newScenePhase in
                            if initialAppearFinished == nil {
                                initialAppearFinished = true
                                return
                            }
                            if newScenePhase == .active && initialAppearFinished == true {
                                managePushNotificationsOnAppAppear(notificationAccessRepresentable: self.notificationAccess, registerForRemoteNotifications: false)
                            }
                        }
                        
                        Spacer(minLength: 0)
                        
                        TabBar()
                            .environmentObject(tabBarItems)
                    } else {
                        SplashScreenStartView()
                    }
                }
                .onAppear {
                    if currentSetting.entity!.splashScreensFinished == false && currentSetting.entity!.showWhatsNew == true {
                        currentSetting.changeShowWhatsNew(newValue: false)
                    }
                }
                .onChange(of: crtNotifiSetting.entity!.changesButErrorUploading) { errorOccurred in
                    if errorOccurred == true {
                        tryNotificationUploadAfterFailed(
                            Int(currentSetting.entity!.regionIdentifier),
                            currentSetting.entity!.pricesWithVAT ? 1 : 0,
                            crtNotifiSetting,
                            networkManager)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: scenePhase) { newScenePhase in
            if newScenePhase == .active {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
}
