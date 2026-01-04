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
    
    // Debug: Track if delegate methods are being called
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse,
           let url = httpResponse.url {
            print("🔵 [Delegate] Response received: \(url.absoluteString) - Status: \(httpResponse.statusCode)")
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let url = task.originalRequest?.url {
            if let error = error {
                print("🔴 [Delegate] Task failed: \(url.absoluteString) - Error: \(error.localizedDescription)")
            } else {
                print("🟢 [Delegate] Task completed: \(url.absoluteString)")
            }
        }
    }
}


