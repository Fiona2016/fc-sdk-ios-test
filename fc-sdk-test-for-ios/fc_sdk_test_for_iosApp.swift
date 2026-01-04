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
        let version = "1.1.0"

        Flashcat.verbosityLevel = .debug

        Flashcat.initialize(
            with: Flashcat.Configuration(
                clientToken: clientToken,
                env: environment,
                site: .staging,
                service: service,
                version: version
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
                urlSessionTracking: .init(
                    firstPartyHostsTracing: .traceWithHeaders(
                        hostsWithHeaders: [
                            "localhost:5173": [.tracecontext],
                            "localhost:3000": [.tracecontext],
                            "hacker-news.firebaseio.com": [.tracecontext]
                        ]
                    )
                )
            )
        )

        // CRITICAL: Must be called AFTER RUM.enable() and BEFORE any URLSession is created
        URLSessionInstrumentation.enable(
            with: .init(delegateClass: InstrumentedURLSessionDelegate.self)
        )

        CrashReporting.enable()
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
        print("✅ URLSessionInstrumentation enabled with delegate: InstrumentedURLSessionDelegate")
        print("✅ First-party tracing hosts: localhost:5173, hacker-news.firebaseio.com")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
