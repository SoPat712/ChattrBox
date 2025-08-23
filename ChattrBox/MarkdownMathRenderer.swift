import SwiftUI
import WebKit
import Markdown

struct MarkdownMathRenderer: View {
    let content: String
    let fontSize: Double
    let isStreaming: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        WebViewRenderer(
            content: content,
            fontSize: fontSize,
            colorScheme: colorScheme
        )
        .frame(minHeight: 20)
        // Remove fixedSize to allow natural expansion
    }
}

// Custom WebView that reports its content height
class DynamicHeightWebView: WKWebView {
    var contentHeight: CGFloat = 20 {
        didSet {
            if contentHeight != oldValue {
                invalidateIntrinsicContentSize()
                superview?.needsLayout = true
            }
        }
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: contentHeight)
    }
}

struct WebViewRenderer: NSViewRepresentable {
    let content: String
    let fontSize: Double
    let colorScheme: ColorScheme
    
    func makeNSView(context: Context) -> DynamicHeightWebView {
        let configuration = WKWebViewConfiguration()
        
        // Add message handler for height changes
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "heightChanged")
        configuration.userContentController = contentController
        
        let webView = DynamicHeightWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Make background transparent
        webView.setValue(false, forKey: "drawsBackground")
        
        // Disable scrolling - we want the WebView to expand to fit content
        webView.enclosingScrollView?.hasVerticalScroller = false
        webView.enclosingScrollView?.hasHorizontalScroller = false
        webView.enclosingScrollView?.verticalScrollElasticity = .none
        webView.enclosingScrollView?.horizontalScrollElasticity = .none
        
        // Set up the coordinator with a reference to the webView
        context.coordinator.webView = webView
        
        return webView
    }
    
    func updateNSView(_ webView: DynamicHeightWebView, context: Context) {
        let htmlContent = generateHTML()
        print("🔄 Loading HTML content: \(content.count) chars -> \(htmlContent.count) HTML chars")
        webView.loadHTMLString(htmlContent, baseURL: nil)
        
        // Update coordinator reference
        context.coordinator.webView = webView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func generateHTML() -> String {
        let markdownHTML = convertMarkdownToHTML(content)
        
        let textColor = colorScheme == .dark ? "#FFFFFF" : "#000000"
        let codeBlockBg = colorScheme == .dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)"
        let inlineCodeBg = colorScheme == .dark ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.12)"
        let tableBorder = colorScheme == .dark ? "rgba(255,255,255,0.2)" : "rgba(0,0,0,0.2)"
        let tableHeaderBg = colorScheme == .dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.08)"
        let blockquoteBorder = colorScheme == .dark ? "rgba(255,255,255,0.3)" : "rgba(0,0,0,0.3)"
        let hrColor = colorScheme == .dark ? "rgba(255,255,255,0.2)" : "rgba(0,0,0,0.2)"
        
        return """
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    
    <!-- KaTeX CSS -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.css" integrity="sha384-5TcZemv2l/9On385z///+d7MSYlvIEw9FuZTIdZ14vJLqWphw7e7ZPuOiCHJcFCP" crossorigin="anonymous">
    
    <!-- Highlight.js CSS -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/styles/\(colorScheme == .dark ? "github-dark" : "github").min.css" integrity="\(colorScheme == .dark ? "sha512-rO+olRTkcf304DQBxSWxln8JXCzTHlKnIdnMUwYvQa9/Jd4cQaNkItIUj6Z4nvW1dqK0SKXLbn9h4KwZTNTLzA==" : "sha512-0aPQyyeZrWj9sCA46UlmWgKOP0mUipLQ6OZXu8l4IcAmD2u31EPEy9VcIMvl7SoAaKe8bLXZhYoMaE/in+gcgA==")" crossorigin="anonymous">
    
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
            font-size: \(fontSize)px;
            line-height: 1.6;
            color: \(textColor);
            margin: 0;
            padding: 0;
            background: transparent;
            word-wrap: break-word;
            overflow-wrap: break-word;
            overflow-y: hidden;
            overflow-x: auto;
            height: auto;
            min-height: auto;
        }
        
        /* Typography */
        p {
            margin: 0 0 16px 0;
        }
        
        h1, h2, h3, h4, h5, h6 {
            margin: 24px 0 16px 0;
            font-weight: 600;
            line-height: 1.3;
        }
        
        h1:first-child, h2:first-child, h3:first-child,
        h4:first-child, h5:first-child, h6:first-child {
            margin-top: 0;
        }
        
        h1 { font-size: \(fontSize * 2.0)px; }
        h2 { font-size: \(fontSize * 1.6)px; }
        h3 { font-size: \(fontSize * 1.3)px; }
        h4 { font-size: \(fontSize * 1.1)px; }
        h5 { font-size: \(fontSize)px; }
        h6 { font-size: \(fontSize * 0.9)px; opacity: 0.8; }
        
        /* Code styling */
        pre {
            background: \(codeBlockBg);
            border-radius: 8px;
            padding: 16px;
            margin: 16px 0;
            overflow-x: auto;
            font-size: \(fontSize * 0.85)px;
            line-height: 1.4;
        }
        
        code {
            font-family: 'SF Mono', Monaco, 'Cascadia Code', Consolas, monospace;
            font-size: \(fontSize * 0.85)px;
        }
        
        :not(pre) > code {
            background: \(inlineCodeBg);
            padding: 2px 6px;
            border-radius: 4px;
            white-space: nowrap;
        }
        
        pre code {
            background: none;
            padding: 0;
            white-space: pre;
        }
        
        /* Lists */
        ul, ol {
            margin: 16px 0;
            padding-left: 24px;
        }
        
        li {
            margin: 4px 0;
        }
        
        /* Tables - with horizontal scrolling support */
        .table-container {
            overflow-x: auto;
            margin: 16px 0;
            max-width: 100%;
        }
        
        table {
            border-collapse: collapse;
            width: auto;
            min-width: 100%;
            margin: 0;
            font-size: \(fontSize * 0.9)px;
            white-space: nowrap;
        }
        
        th, td {
            border: 1px solid \(tableBorder);
            padding: 8px 12px;
            text-align: left;
            white-space: nowrap;
        }
        
        th {
            background: \(tableHeaderBg);
            font-weight: 600;
            position: sticky;
            top: 0;
        }
        
        /* Allow text wrapping in table cells if needed */
        table.wrap-text th,
        table.wrap-text td {
            white-space: normal;
            word-wrap: break-word;
            max-width: 200px;
        }
        
        /* Blockquotes */
        blockquote {
            border-left: 4px solid \(blockquoteBorder);
            margin: 16px 0;
            padding-left: 16px;
            opacity: 0.8;
            font-style: italic;
        }
        
        /* Links */
        a {
            color: #007AFF;
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
        
        /* Horizontal rules */
        hr {
            border: none;
            border-top: 1px solid \(hrColor);
            margin: 24px 0;
        }
        
        /* Math styling */
        .katex {
            font-size: 1em !important;
        }
        
        .katex-display {
            margin: 16px 0;
            text-align: center;
            overflow-x: auto;
        }
        
        /* Emphasis */
        strong {
            font-weight: 600;
        }
        
        em {
            font-style: italic;
        }
        
        /* Task lists */
        .task-list-item {
            list-style: none;
            margin-left: -20px;
        }
        
        .task-list-item input[type="checkbox"] {
            margin-right: 8px;
        }
        
        /* Strikethrough */
        del {
            text-decoration: line-through;
            opacity: 0.7;
        }
        
        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border-radius: 4px;
        }
        
        /* Scrollbar styling for horizontal scroll */
        ::-webkit-scrollbar {
            height: 8px;
        }
        
        ::-webkit-scrollbar-track {
            background: transparent;
        }
        
        ::-webkit-scrollbar-thumb {
            background: \(colorScheme == .dark ? "rgba(255,255,255,0.3)" : "rgba(0,0,0,0.3)");
            border-radius: 4px;
        }
        
        ::-webkit-scrollbar-thumb:hover {
            background: \(colorScheme == .dark ? "rgba(255,255,255,0.5)" : "rgba(0,0,0,0.5)");
        }
    </style>
</head>
<body>
    \(markdownHTML)
    
    <!-- KaTeX JS -->
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.js" integrity="sha384-cMkvdD8LoxVzGF/RPUKAcvmm49FQ0oxwDF3BGKtDXcEc+T1b2N+teh/OJfpU0jr6" crossorigin="anonymous"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/contrib/auto-render.min.js" integrity="sha384-hCXGrW6PitJEwbkoStFjeJxv+fSOOQKOPbJxSfM6G5sWZjAyWhXiTIIAmQqnlLlh" crossorigin="anonymous"></script>
    
    <!-- Highlight.js JS -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js" integrity="sha512-WUU2MuRJtw1SBkeSvqNP60HdJnKPcKHHg2D34CthrRqrLzCZBhq6y8Rg+D8wj0XOgzKtMl30pAQUrCR2N6aL1w==" crossorigin="anonymous"></script>
    
    <script>
        function initializeContent() {
            // Highlight code blocks
            if (typeof hljs !== 'undefined') {
                hljs.highlightAll();
            }
            
            // Render math with KaTeX
            if (typeof renderMathInElement !== 'undefined') {
                renderMathInElement(document.body, {
                    delimiters: [
                        {left: '$$', right: '$$', display: true},
                        {left: '$', right: '$', display: false},
                        {left: '\\\\(', right: '\\\\)', display: false},
                        {left: '\\\\[', right: '\\\\]', display: true}
                    ],
                    throwOnError: false,
                    errorColor: '#cc0000'
                });
            }
            
            // Wrap tables in scrollable containers
            wrapTablesForScrolling();
            
            // Notify SwiftUI about content height
            updateHeight();
        }
        
        function wrapTablesForScrolling() {
            const tables = document.querySelectorAll('table');
            tables.forEach(table => {
                if (!table.parentElement.classList.contains('table-container')) {
                    const wrapper = document.createElement('div');
                    wrapper.className = 'table-container';
                    table.parentNode.insertBefore(wrapper, table);
                    wrapper.appendChild(table);
                }
            });
        }
        
        function updateHeight() {
            // Force layout calculation
            document.body.style.height = 'auto';
            
            const height = Math.max(
                document.body.scrollHeight,
                document.body.offsetHeight,
                document.documentElement.scrollHeight,
                document.documentElement.offsetHeight
            );
            
            // Set explicit height to prevent vertical scrolling
            document.body.style.height = height + 'px';
            document.documentElement.style.height = height + 'px';
            
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChanged) {
                window.webkit.messageHandlers.heightChanged.postMessage({ height: height });
            }
        }
        
        // Initialize when all resources are loaded
        window.addEventListener('load', function() {
            setTimeout(initializeContent, 100);
        });
        
        // Also try to initialize immediately if already loaded
        if (document.readyState === 'complete') {
            setTimeout(initializeContent, 100);
        }
        
        // Watch for content changes (for streaming updates)
        const observer = new MutationObserver(function() {
            setTimeout(function() {
                if (typeof hljs !== 'undefined') hljs.highlightAll();
                if (typeof renderMathInElement !== 'undefined') {
                    renderMathInElement(document.body, {
                        delimiters: [
                            {left: '$$', right: '$$', display: true},
                            {left: '$', right: '$', display: false}
                        ],
                        throwOnError: false
                    });
                }
                wrapTablesForScrolling();
                updateHeight();
            }, 50);
        });
        
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            characterData: true
        });
    </script>
</body>
</html>
"""
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        print("🔄 Converting markdown with enhanced processing: \(markdown.count) characters")
        print("📝 Raw input: '\(markdown)'")
        
        // Use the enhanced markdown processing directly since swift-markdown's HTML API is complex
        let html = enhancedMarkdownProcessing(markdown)
        print("📄 Generated HTML: '\(html)'")
        return html
    }
    
    /// Enhanced fallback markdown processing when swift-markdown fails
    private func enhancedMarkdownProcessing(_ markdown: String) -> String {
        print("🚀 Enhanced Markdown: Processing \(markdown.count) characters")
        let lines = markdown.components(separatedBy: .newlines)
        var result: [String] = []
        
        var inCodeBlock = false
        var inTable = false
        var tableHeaderProcessed = false
        
        for line in lines {
            var processedLine = line
            
            // Handle code blocks first (they have priority)
            if line.hasPrefix("```") {
                if !inCodeBlock {
                    // Start code block
                    inCodeBlock = true
                    let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    processedLine = "<pre><code class=\"language-\(language)\">"
                } else {
                    // End code block
                    inCodeBlock = false
                    processedLine = "</code></pre>"
                }
                result.append(processedLine)
                continue
            }
            
            // Don't process anything inside code blocks
            if inCodeBlock {
                result.append(line)
                continue
            }
            
            // Handle tables
            if line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !inTable {
                    inTable = true
                    tableHeaderProcessed = false
                    result.append("<table>")
                }
                
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Check if this is a separator line
                let isSeparator = trimmed.replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "|", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: ":", with: "").isEmpty
                
                if isSeparator && !tableHeaderProcessed {
                    // This is the separator, start tbody
                    result.append("</thead><tbody>")
                    tableHeaderProcessed = true
                } else if !isSeparator {
                    let cells = trimmed.components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    
                    if !tableHeaderProcessed {
                        // This is header row
                        result.append("<thead><tr>")
                        for cell in cells {
                            result.append("<th>\(processInlineFormatting(cell))</th>")
                        }
                        result.append("</tr>")
                    } else {
                        // This is data row
                        result.append("<tr>")
                        for cell in cells {
                            result.append("<td>\(processInlineFormatting(cell))</td>")
                        }
                        result.append("</tr>")
                    }
                }
                continue
            } else if inTable {
                // End table
                inTable = false
                result.append("</tbody></table>")
            }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                result.append("")
                continue
            }
            
            // Headers
            if trimmed.hasPrefix("######") {
                processedLine = "<h6>\(processInlineFormatting(String(trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces))))</h6>"
            } else if trimmed.hasPrefix("#####") {
                processedLine = "<h5>\(processInlineFormatting(String(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))))</h5>"
            } else if trimmed.hasPrefix("####") {
                processedLine = "<h4>\(processInlineFormatting(String(trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces))))</h4>"
            } else if trimmed.hasPrefix("###") {
                processedLine = "<h3>\(processInlineFormatting(String(trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces))))</h3>"
            } else if trimmed.hasPrefix("##") {
                processedLine = "<h2>\(processInlineFormatting(String(trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces))))</h2>"
            } else if trimmed.hasPrefix("#") {
                processedLine = "<h1>\(processInlineFormatting(String(trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces))))</h1>"
            }
            // Horizontal rule
            else if trimmed == "---" || trimmed == "***" {
                processedLine = "<hr>"
            }
            // Blockquote
            else if trimmed.hasPrefix(">") {
                processedLine = "<blockquote>\(processInlineFormatting(String(trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces))))</blockquote>"
            }
            // Unordered list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                processedLine = "<li>\(processInlineFormatting(content))</li>"
            }
            // Ordered list
            else if let match = trimmed.range(of: #"^\d+\. "#, options: .regularExpression) {
                let content = String(trimmed[match.upperBound...])
                processedLine = "<li>\(processInlineFormatting(content))</li>"
            }
            // Task list
            else if trimmed.hasPrefix("- [ ] ") {
                let content = String(trimmed.dropFirst(6))
                processedLine = "<li class=\"task-list-item\"><input type=\"checkbox\" disabled> \(processInlineFormatting(content))</li>"
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let content = String(trimmed.dropFirst(6))
                processedLine = "<li class=\"task-list-item\"><input type=\"checkbox\" checked disabled> \(processInlineFormatting(content))</li>"
            }
            // Regular paragraph
            else {
                processedLine = "<p>\(processInlineFormatting(trimmed))</p>"
            }
            
            result.append(processedLine)
        }
        
        // Close any open table
        if inTable {
            result.append("</tbody></table>")
        }
        
        // Wrap consecutive list items in proper list tags
        let finalHTML = wrapListItems(result.joined(separator: "\n"))
        
        print("🚀 Enhanced Markdown: Generated \(finalHTML.count) chars HTML with GFM support")
        return finalHTML
    }
    
    private func processInlineFormatting(_ text: String) -> String {
        var result = text
        
        // Bold (** or __)
        result = result.replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"__(.*?)__"#, with: "<strong>$1</strong>", options: .regularExpression)
        
        // Italic (* or _)
        result = result.replacingOccurrences(of: #"\*(.*?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_(.*?)_"#, with: "<em>$1</em>", options: .regularExpression)
        
        // Strikethrough
        result = result.replacingOccurrences(of: #"~~(.*?)~~"#, with: "<del>$1</del>", options: .regularExpression)
        
        // Inline code
        result = result.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        
        // Links
        result = result.replacingOccurrences(of: #"\[(.*?)\]\((.*?)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        
        return result
    }
    
    private func wrapListItems(_ html: String) -> String {
        var result = html
        
        // Wrap unordered list items
        result = result.replacingOccurrences(of: #"(<li(?:\s+class="[^"]*")?>[^<]*</li>(?:\s*<li(?:\s+class="[^"]*")?>[^<]*</li>)*)"#, with: "<ul>$1</ul>", options: .regularExpression)
        
        // Clean up consecutive ul tags
        result = result.replacingOccurrences(of: #"</ul>\s*<ul>"#, with: "", options: .regularExpression)
        
        return result
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: DynamicHeightWebView?
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading")
            
            // Force height calculation after load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                webView.evaluateJavaScript("updateHeight();") { _, _ in }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView failed to load: \(error)")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChanged",
               let body = message.body as? [String: Any],
               let height = body["height"] as? Double {
                
                print("📏 WebView content height received: \(height)")
                
                DispatchQueue.main.async {
                    if let dynamicWebView = self.webView {
                        dynamicWebView.contentHeight = max(20, CGFloat(height))
                    }
                }
            }
        }
    }
}
