//
//  InstrumentedURLSessionDelegate.swift
//  fc-sdk-test-for-ios
//
//  Created by Cursor on 2025/12/30.
//

import Foundation

/// A dedicated URLSessionDataDelegate used by the demo app to bind Flashcat URLSession instrumentation.
///
/// The instrumentation API requires providing a delegate *class* to swizzle. The demo uses a URLSession
/// configured with this delegate so that network requests (e.g. Hacker News API calls) are captured as RUM resources.
final class InstrumentedURLSessionDelegate: NSObject, URLSessionDataDelegate {
    static let shared = InstrumentedURLSessionDelegate()
}


