//
//  ContentView.swift
//  fc-sdk-test-for-ios
//
//  Created by Fiona on 2025/12/29.
//

import SwiftUI
import FlashcatRUM
import WebKit

struct ContentView: View {
    var body: some View {
        TabView {
            HackerNewsTabView()
                .tabItem {
                    Label("HackerNews", systemImage: "newspaper")
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
    
    func loadTopStories() {
        isLoading = true
        errorMessage = nil
        
        // Fetch top story IDs
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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
                // Fetch first 30 stories
                self?.loadStories(ids: Array(storyIds.prefix(30)))
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Decode error: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }
        }.resume()
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
            
            URLSession.shared.dataTask(with: url) { data, response, error in
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
        
        URLSession.shared.dataTask(with: url) { data, response, error in
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

// MARK: - RUM Test Tab

private struct RUMTestTabView: View {
    @State private var lastActionResult: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("RUM 测试")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("错误和崩溃测试")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    testSection
                    
                    if !lastActionResult.isEmpty {
                        resultCard
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
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
                subtitle: "强制崩溃应用（Fatal Error）",
                icon: "xmark.octagon.fill",
                color: .red
            ) {
                triggerCrash()
            }
        }
    }
    
    private func testButton(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        lastActionResult = "⚠️ 应用将在1秒后崩溃..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            forceCrash()
        }
    }
    
    private func forceCrash() {
        // Force unwrap nil to trigger a crash
        let array: [Int]? = nil
        let _ = array![0] // This will crash with fatal error
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
                
                EmptyWebView()
                
                Text("空白 WebView")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}

private struct EmptyWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Load empty HTML
        let emptyHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Empty WebView</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background-color: #f5f5f5;
                }
                .container {
                    text-align: center;
                    color: #666;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h2>Empty WebView</h2>
                <p>This is an empty WebView for testing</p>
            </div>
        </body>
        </html>
        """
        
        webView.loadHTMLString(emptyHTML, baseURL: nil)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }
}

#Preview {
    ContentView()
}
