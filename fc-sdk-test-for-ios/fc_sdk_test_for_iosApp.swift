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
        let service = "fc-sdk-test-for-ios"

        Flashcat.verbosityLevel = .debug

        Flashcat.initialize(
            with: Flashcat.Configuration(
                clientToken: clientToken,
                env: environment,
                site: .staging,
                service: service,
            ),
            trackingConsent: .granted
        )

        

        RUM.enable(
            with: RUM.Configuration(
                applicationID: appID,
                uiKitViewsPredicate: DefaultUIKitRUMViewsPredicate(),
                uiKitActionsPredicate: DefaultUIKitRUMActionsPredicate(),
                swiftUIViewsPredicate: DefaultSwiftUIRUMViewsPredicate(),
                swiftUIActionsPredicate: DefaultSwiftUIRUMActionsPredicate(isLegacyDetectionEnabled: true),
                urlSessionTracking: RUM.Configuration.URLSessionTracking()
            )
        )

        // CRITICAL: Must be called AFTER RUM.enable() and BEFORE any URLSession is created
        URLSessionInstrumentation.enable(
            with: .init(delegateClass: InstrumentedURLSessionDelegate.self)
        )

        CrashReporting.enable()

        // Basic local verification: print current session ID after the first view is likely started.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            RUMMonitor.shared().currentSessionID { sessionId in
                print("✅ Current RUM session ID: \(sessionId ?? "nil")")
            }
        }
        
        // Set user info
        Flashcat.setUserInfo(
            id: "test-user",
            name: "Test User",
            email: "test@fc-sdk.app"
        )
        
        print("✅ Flashcat SDK initialized successfully!")
        print("✅ RUM enabled with Application ID: \(appID)")
        print("✅ CrashReporting enabled")
        print("✅ Environment: \(environment)")
        print("✅ Service: \(service)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
