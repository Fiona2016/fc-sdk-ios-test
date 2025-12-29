//
//  fc_sdk_test_for_iosApp.swift
//  fc-sdk-test-for-ios
//
//  Created by Fiona on 2025/12/29.
//

import SwiftUI
import FlashcatCore
import FlashcatRUM
import FlashcatCrashReporting

@main
struct fc_sdk_test_for_iosApp: App {
    init() {
        let appID = "LrctR7mdssyQmiWPEE4F5G"
        let clientToken = "c6e5f26a799055678169df7f5eb8ec41131"
        let environment = "local"

        Flashcat.initialize(
            with: Flashcat.Configuration(
                clientToken: clientToken,
                env: environment,
                site: .staging
            ),
            trackingConsent: .granted
        )

        RUM.enable(
            with: RUM.Configuration(
                applicationID: appID,
                uiKitViewsPredicate: DefaultUIKitRUMViewsPredicate(),
                uiKitActionsPredicate: DefaultUIKitRUMActionsPredicate()
            )
        )

        CrashReporting.enable()
        
        // Set user info
        Flashcat.setUserInfo(
            id: "test-user",
            name: "Test User",
            email: "test@fc-sdk.app"
        )
        
        print("✅ Flashcat SDK initialized successfully!")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
