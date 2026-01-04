//
//  ContentView.swift
//  fc-sdk-test-for-ios
//
//  Created by Fiona on 2025/12/29.
//

import SwiftUI
import FlashcatRUM
import WebKit
import FlashcatWebViewTracking
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            HackerNewsTabView()
                .tabItem {
                    Label("HackerNews", systemImage: "newspaper")
                }
            
            StaticAssetsTabView()
                .tabItem {
                    Label("静态资源", systemImage: "photo.on.rectangle")
                }

            RUMTestTabView()
                .tabItem {
                    Label("RUM测试", systemImage: "testtube.2")
                }
            
            WebViewTabView()
                .tabItem {
                    Label("WebView", systemImage: "globe")
                }
        }
    }
}

// MARK: - Hacker News Tab

struct HackerNewsItem: Identifiable, Codable {
    let id: Int
    let title: String
    let url: String?
    let score: Int?
    let by: String?
    let time: Int?
    let descendants: Int?
    
    // Computed property for display date
    var displayDate: String {
        guard let time = time else { return "Unknown" }
        let date = Date(timeIntervalSince1970: TimeInterval(time))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct HackerNewsDetail: Codable {
    let id: Int
    let title: String
    let url: String?
    let score: Int?
    let by: String?
    let time: Int?
    let text: String?
    let descendants: Int?
}

class HackerNewsViewModel: ObservableObject {
    @Published var stories: [HackerNewsItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private lazy var session: URLSession = {
        URLSession(
            configuration: .ephemeral,
            delegate: InstrumentedURLSessionDelegate.shared,
            delegateQueue: nil
        )
    }()
    
    func loadTopStories() {
        isLoading = true
        errorMessage = nil
        
        // Fetch top story IDs
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ HN topstories request completed: HTTP \(httpResponse.statusCode)")
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    self?.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self?.errorMessage = "No data received"
                    self?.isLoading = false
                }
                return
            }
            
            do {
                let storyIds = try JSONDecoder().decode([Int].self, from: data)
                print("✅ HN loaded \(storyIds.count) story IDs, will fetch first 30")
                // Fetch first 30 stories
                self?.loadStories(ids: Array(storyIds.prefix(30)))
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Decode error: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }
        }
        print("📡 Starting HN topstories request to: \(url)")
        task.resume()
    }
    
    private func loadStories(ids: [Int]) {
        let group = DispatchGroup()
        var loadedStories: [HackerNewsItem] = []
        
        for id in ids {
            group.enter()
            guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else {
                group.leave()
                continue
            }
            
            session.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                
                guard let data = data,
                      let story = try? JSONDecoder().decode(HackerNewsItem.self, from: data) else {
                    return
                }
                
                loadedStories.append(story)
            }.resume()
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.stories = loadedStories.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
            self?.isLoading = false
            print("✅ HackerNews loaded stories count: \(loadedStories.count)")
        }
    }
}

private struct HackerNewsTabView: View {
    @StateObject private var viewModel = HackerNewsViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading stories...")
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            RUMMonitor.shared().addAction(
                                type: .tap,
                                name: "Retry Loading HN Stories",
                                attributes: [:]
                            )
                            viewModel.loadTopStories()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if viewModel.stories.isEmpty {
                    VStack(spacing: 16) {
                        Text("No stories loaded")
                            .foregroundStyle(.secondary)
                        Button("Load Stories") {
                            RUMMonitor.shared().addAction(
                                type: .tap,
                                name: "Load HN Stories",
                                attributes: [:]
                            )
                            viewModel.loadTopStories()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List(viewModel.stories) { story in
                        NavigationLink(destination: HackerNewsDetailView(itemId: story.id)) {
                            HackerNewsRow(story: story)
                        }
                    }
                }
            }
            .navigationTitle("Hacker News")
            .onAppear {
                if viewModel.stories.isEmpty {
                    viewModel.loadTopStories()
                }
            }
        }
    }
}

private struct HackerNewsRow: View {
    let story: HackerNewsItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(story.title)
                .font(.headline)
                .lineLimit(3)
            
            HStack {
                if let score = story.score {
                    Label("\(score)", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let by = story.by {
                    Text("by \(by)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(story.displayDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HackerNewsDetailView: View {
    let itemId: Int
    @State private var detail: HackerNewsDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundStyle(.red)
                        .padding()
                } else if let detail = detail {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(detail.title)
                            .font(.title2)
                            .bold()
                        
                        HStack {
                            if let score = detail.score {
                                Label("\(score) points", systemImage: "arrow.up")
                            }
                            if let by = detail.by {
                                Text("by \(by)")
                            }
                            if let descendants = detail.descendants {
                                Label("\(descendants) comments", systemImage: "bubble.right")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        Divider()
                        
                        if let urlString = detail.url, let url = URL(string: urlString) {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "link")
                                    Text(url.host ?? urlString)
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        if let text = detail.text {
                            Text(attributedText(from: text))
                                .font(.body)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Story Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDetail()
        }
    }
    
    private func loadDetail() {
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(itemId).json") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession(
            configuration: .ephemeral,
            delegate: InstrumentedURLSessionDelegate.shared,
            delegateQueue: nil
        ).dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    isLoading = false
                    return
                }
                
                do {
                    detail = try JSONDecoder().decode(HackerNewsDetail.self, from: data)
                    isLoading = false
                } catch {
                    errorMessage = "Decode error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }.resume()
    }
    
    // Simple HTML to AttributedString conversion
    private func attributedText(from html: String) -> AttributedString {
        let cleaned = html.replacingOccurrences(of: "<p>", with: "\n\n")
            .replacingOccurrences(of: "</p>", with: "")
            .replacingOccurrences(of: "<i>", with: "")
            .replacingOccurrences(of: "</i>", with: "")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
        
        return AttributedString(cleaned)
    }
}

// MARK: - Static Assets Tab

private struct StaticIllustration: Identifiable {
    let id = UUID()
    let assetName: String
    let title: String
    let shouldFail: Bool // Track if this resource should fail
}

private struct StaticAssetsTabView: View {
    private let illustrations: [StaticIllustration] = [
        .init(assetName: "pixabay_illustration_1", title: "Pixabay Illustration #1", shouldFail: false),
        .init(assetName: "pixabay_illustration_2", title: "Pixabay Illustration #2", shouldFail: false),
        .init(assetName: "pixabay_illustration_3", title: "Pixabay Illustration #3", shouldFail: false),
        .init(assetName: "non_existent_image_1", title: "不存在的图片 #1 (404)", shouldFail: true),
        .init(assetName: "missing_asset_2", title: "缺失的资源 #2 (404)", shouldFail: true),
        .init(assetName: "deleted_image_3", title: "已删除的图片 #3 (404)", shouldFail: true)
    ]

    var body: some View {
        NavigationStack {
            List(illustrations) { item in
                StaticIllustrationRow(item: item)
            }
            .navigationTitle("静态资源")
        }
        // NOTE: Removed .trackRUMView - using automatic SwiftUI view tracking instead
    }
}

private struct StaticIllustrationRow: View {
    let item: StaticIllustration
    @State private var didTrack = false

    var body: some View {
        HStack(spacing: 12) {
            // Display placeholder for missing images
            if item.shouldFail {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                }
            } else {
                Image(item.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(item.shouldFail ? .red : .primary)
                Text(item.assetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            if item.shouldFail {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            guard !didTrack else { return }
            didTrack = true
            StaticAssetRUMTracker.trackBundledImageLoad(assetName: item.assetName)
        }
    }
}

private enum StaticAssetRUMTracker {
    static func trackBundledImageLoad(assetName: String) {
        let monitor = RUMMonitor.shared()
        let resourceKey = "bundle-image:\(assetName):\(UUID().uuidString)"
        let urlString = "bundle://Assets.xcassets/\(assetName)"

        monitor.startResource(
            resourceKey: resourceKey,
            httpMethod: .get,
            urlString: urlString,
            attributes: [
                "resource.origin": "bundle",
                "asset.name": assetName
            ]
        )

        let start = CFAbsoluteTimeGetCurrent()
        let image = UIImage(named: assetName)
        let durationMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

        monitor.stopResource(
            resourceKey: resourceKey,
            statusCode: image == nil ? 404 : 200,
            kind: .image,
            size: nil,
            attributes: [
                "duration_ms": durationMs
            ]
        )

        print("✅ Tracked bundled image as RUM resource: \(assetName), duration_ms=\(durationMs), status=\(image == nil ? 404 : 200)")
    }
}

// MARK: - RUM Test Tab

private struct RUMTestTabView: View {
    @State private var lastActionResult: String = ""
    
    // Use static session to avoid lazy var mutation issues in struct
    private static let testSession: URLSession = {
        URLSession(
            configuration: .ephemeral,
            delegate: InstrumentedURLSessionDelegate.shared,
            delegateQueue: nil
        )
    }()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("RUM 测试")
                        .font(.largeTitle)
                        .bold()
                    
                    // Important notice about crash reporting
                    crashReportingNotice
                    
                    Text("错误和崩溃测试")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    testSection
                    
                    Text("Trace 功能测试")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    
                    traceTestSection
                    
                    Text("网络请求失败测试")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    
                    networkFailureSection
                    
                    if !lastActionResult.isEmpty {
                        resultCard
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    private var crashReportingNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("崩溃上报说明")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• 崩溃报告会在下次启动时上报")
                Text("• 通过 Xcode 调试时，调试器会拦截崩溃")
                Text("• 建议：停止调试后，从设备直接启动应用")
                Text("• 触发崩溃后，重新启动查看上报结果")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    private var testSection: some View {
        VStack(spacing: 16) {
            testButton(
                title: "手动上报异常",
                subtitle: "手动添加错误到 RUM",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            ) {
                manuallyReportError()
            }
            
            testButton(
                title: "触发崩溃",
                subtitle: "崩溃后重启应用以上报（需要非调试模式）",
                icon: "xmark.octagon.fill",
                color: .red
            ) {
                triggerCrash()
            }
        }
    }
    
    private var traceTestSection: some View {
        VStack(spacing: 16) {
            testButton(
                title: "测试 localhost:3000",
                subtitle: "发送带 trace headers 的请求",
                icon: "antenna.radiowaves.left.and.right",
                color: .blue
            ) {
                testLocalhost3000()
            }
            
            testButton(
                title: "测试 HackerNews API",
                subtitle: "验证 trace headers 添加",
                icon: "link.circle.fill",
                color: .green
            ) {
                testHackerNewsTrace()
            }
        }
    }
    
    private var networkFailureSection: some View {
        VStack(spacing: 16) {
            testButton(
                title: "404 错误",
                subtitle: "请求不存在的资源",
                icon: "doc.questionmark.fill",
                color: .orange
            ) {
                testNotFoundError()
            }
            
            testButton(
                title: "无效域名",
                subtitle: "请求无法解析的域名",
                icon: "network.slash",
                color: .red
            ) {
                testInvalidDomain()
            }
            
            testButton(
                title: "连接超时",
                subtitle: "请求无响应的服务器",
                icon: "clock.badge.exclamationmark.fill",
                color: .purple
            ) {
                testConnectionTimeout()
            }
            
            testButton(
                title: "错误的 URL",
                subtitle: "使用格式错误的 URL",
                icon: "link.badge.xmark",
                color: .pink
            ) {
                testMalformedURL()
            }
            
            testButton(
                title: "服务器错误 (500)",
                subtitle: "请求会返回服务器错误的接口",
                icon: "server.rack",
                color: .red
            ) {
                testServerError()
            }
        }
    }
    
    private func testButton(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            RUMMonitor.shared().addAction(
                type: .tap,
                name: title,
                attributes: [:]
            )
            action()
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("执行结果")
                .font(.headline)
            Text(lastActionResult)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    // Manually report error with stack trace
    private func manuallyReportError() {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        // Capture stack trace
        let returnAddresses = Thread.callStackReturnAddresses
        let rawStackTrace = returnAddresses.map { address in
            String(format: "0x%016llx", address.uint64Value)
        }.joined(separator: "\n")
        
        // Report to RUM
        RUMMonitor.shared().addError(
            message: "Manual test error at \(timestamp)",
            type: "ManualTestError",
            stack: rawStackTrace,
            source: .custom,
            attributes: [
                "test_type": "manual_error",
                "test_timestamp": timestamp,
                "test_source": "RUMTestTabView"
            ]
        )
        
        lastActionResult = """
        ✅ 手动错误已上报到 RUM
        时间：\(timestamp)
        类型：ManualTestError
        
        错误已成功发送到 Flashcat RUM
        请在控制台查看详情
        """
        
        print("✅ Manual error reported to RUM at \(timestamp)")
    }
    
    // Trigger a crash
    private func triggerCrash() {
        lastActionResult = """
        ⚠️ 应用将在2秒后崩溃...
        
        崩溃后请：
        1. 停止 Xcode 调试（如果在调试）
        2. 从设备/模拟器直接启动应用
        3. 崩溃报告会在启动时自动上报
        4. 查看控制台日志确认上报状态
        """
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            forceCrash()
        }
    }
    
    private func forceCrash() {
        // Force unwrap nil to trigger a crash
        let array: [Int]? = nil
        let _ = array![0] // This will crash with fatal error
    }
    
    // MARK: - Network Failure Tests
    
    private func testNotFoundError() {
        let urlString = "https://httpbin.org/status/404"
        guard let url = URL(string: urlString) else { return }
        
        lastActionResult = "🔄 正在请求 404 接口...\nURL: \(urlString)"
        
        let task = Self.testSession.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    self.lastActionResult = """
                    ✅ 请求完成 - 404 Not Found
                    URL: \(urlString)
                    状态码: \(httpResponse.statusCode)
                    
                    这个请求已被 RUM SDK 捕获为失败的资源
                    """
                    print("✅ 404 Error test completed: HTTP \(httpResponse.statusCode)")
                } else if let error = error {
                    self.lastActionResult = """
                    ❌ 请求失败
                    URL: \(urlString)
                    错误: \(error.localizedDescription)
                    """
                    print("❌ 404 Error test failed: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
    
    private func testInvalidDomain() {
        let urlString = "https://this-domain-does-not-exist-12345.com/api/test"
        guard let url = URL(string: urlString) else { return }
        
        lastActionResult = "🔄 正在请求无效域名...\nURL: \(urlString)"
        
        let task = Self.testSession.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastActionResult = """
                    ✅ DNS 解析失败（预期行为）
                    URL: \(urlString)
                    错误类型: \(type(of: error))
                    错误信息: \(error.localizedDescription)
                    
                    这个网络错误已被 RUM SDK 捕获
                    """
                    print("✅ Invalid domain test completed: \(error.localizedDescription)")
                } else {
                    self.lastActionResult = "意外成功（不应该发生）"
                }
            }
        }
        task.resume()
    }
    
    private func testConnectionTimeout() {
        // Using httpbin's delay endpoint to simulate timeout
        let urlString = "https://httpbin.org/delay/30"
        guard let url = URL(string: urlString) else { return }
        
        lastActionResult = "🔄 正在测试连接超时...\nURL: \(urlString)\n⏱️ 等待响应（30秒延迟）"
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // 5 seconds timeout
        
        let task = Self.testSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastActionResult = """
                    ✅ 请求超时（预期行为）
                    URL: \(urlString)
                    超时时间: 5秒
                    错误信息: \(error.localizedDescription)
                    
                    这个超时错误已被 RUM SDK 捕获
                    """
                    print("✅ Timeout test completed: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    self.lastActionResult = """
                    意外成功 - HTTP \(httpResponse.statusCode)
                    （请求应该超时但却成功了）
                    """
                }
            }
        }
        task.resume()
    }
    
    private func testMalformedURL() {
        // Create an intentionally malformed request
        let urlString = "https://httpbin.org/get?param=<invalid characters>"
        
        lastActionResult = """
        🔄 正在测试格式错误的 URL...
        URL: \(urlString)
        """
        
        // Force create URL that might have issues
        if let url = URL(string: urlString) {
            let task = Self.testSession.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.lastActionResult = """
                        ✅ URL 请求失败（预期行为）
                        URL: \(urlString)
                        错误: \(error.localizedDescription)
                        
                        这个错误已被 RUM SDK 捕获
                        """
                    } else if let httpResponse = response as? HTTPURLResponse {
                        self.lastActionResult = """
                        ⚠️ 请求成功 - HTTP \(httpResponse.statusCode)
                        URL: \(urlString)
                        （某些格式问题可能被自动修复）
                        """
                    }
                }
            }
            task.resume()
        } else {
            lastActionResult = """
            ❌ URL 创建失败
            无法创建 URL 对象: \(urlString)
            这是在 URL 构造阶段就失败了
            """
        }
    }
    
    private func testServerError() {
        let urlString = "https://httpbin.org/status/500"
        guard let url = URL(string: urlString) else { return }
        
        lastActionResult = "🔄 正在请求 500 服务器错误接口...\nURL: \(urlString)"
        
        let task = Self.testSession.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    self.lastActionResult = """
                    ✅ 请求完成 - 500 Internal Server Error
                    URL: \(urlString)
                    状态码: \(httpResponse.statusCode)
                    
                    这个服务器错误已被 RUM SDK 捕获为失败的资源
                    """
                    print("✅ 500 Error test completed: HTTP \(httpResponse.statusCode)")
                } else if let error = error {
                    self.lastActionResult = """
                    ❌ 请求失败
                    URL: \(urlString)
                    错误: \(error.localizedDescription)
                    """
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Trace Tests
    
    private func testLocalhost3000() {
        let urlString = "http://localhost:3000/api"
        guard let url = URL(string: urlString) else { return }
        
        lastActionResult = "🔄 正在请求 localhost:3000/api...\n💡 请在 Proxyman 中查看 trace headers"
        
        let task = Self.testSession.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    self.lastActionResult = """
                    ✅ 请求完成
                    URL: \(urlString)
                    状态码: \(httpResponse.statusCode)
                    
                    📋 在 Proxyman 中应该能看到以下 headers:
                    • x-datadog-trace-id
                    • x-datadog-parent-id
                    • x-datadog-origin: rum
                    • x-datadog-sampling-priority
                    • traceparent
                    • tracestate
                    
                    这个请求已被 RUM SDK 追踪为 Resource
                    """
                    print("✅ localhost:3000 trace test completed: HTTP \(httpResponse.statusCode)")
                } else if let error = error {
                    self.lastActionResult = """
                    ⚠️ 请求失败（预期情况，如果服务未启动）
                    URL: \(urlString)
                    错误: \(error.localizedDescription)
                    
                    💡 提示:
                    1. 确保在 localhost:3000 启动了服务器
                    2. 或者使用 Proxyman 查看请求详情
                    3. 即使请求失败，trace headers 也应该被添加
                    
                    在 Proxyman 中查找这个请求，验证 headers
                    """
                    print("⚠️ localhost:3000 connection failed (expected if server not running): \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
    
    private func testHackerNewsTrace() {
        let urlString = "https://hacker-news.firebaseio.com/v0/item/8863.json"
        guard let url = URL(string: urlString) else { return }
        
        lastActionResult = "🔄 正在请求 HackerNews API...\n💡 请在 Proxyman 中查看 trace headers"
        
        let task = Self.testSession.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    var responsePreview = ""
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let title = json["title"] as? String {
                        responsePreview = "\n📰 文章: \(title)"
                    }
                    
                    self.lastActionResult = """
                    ✅ 请求成功
                    URL: \(urlString)
                    状态码: \(httpResponse.statusCode)\(responsePreview)
                    
                    📋 在 Proxyman 中检查 Request Headers:
                    ✓ x-datadog-trace-id
                    ✓ x-datadog-parent-id
                    ✓ x-datadog-origin: rum
                    ✓ traceparent (W3C format)
                    ✓ tracestate
                    
                    🎯 这个请求应该:
                    1. 在 Proxyman 中显示完整的 trace headers
                    2. 在 RUM 后台显示为 Resource
                    3. Trace ID 关联到当前 RUM session
                    """
                    print("✅ HackerNews trace test completed: HTTP \(httpResponse.statusCode)")
                } else if let error = error {
                    self.lastActionResult = """
                    ❌ 请求失败
                    URL: \(urlString)
                    错误: \(error.localizedDescription)
                    
                    请检查网络连接
                    """
                    print("❌ HackerNews trace test failed: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
}

// MARK: - WebView Tab

private struct WebViewTabView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("WebView 测试")
                    .font(.title2)
                    .bold()
                    .padding()
                
                LocalhostWebView(url: URL(string: "http://localhost:5173/")!)
                
                Text("加载: http://localhost:5173/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        // NOTE: Removed .trackRUMView - using automatic SwiftUI view tracking instead
    }
}

private struct LocalhostWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Enable WebView-to-RUM bridging for the specified hosts only.
        WebViewTracking.enable(webView: webView, hosts: ["localhost"])

        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

#Preview {
    ContentView()
}
