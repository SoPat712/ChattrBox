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
    private var _contentHeight: CGFloat = 20
    private var isUpdatingHeight = false
    
    var contentHeight: CGFloat {
        get { _contentHeight }
        set {
            let newHeight = max(20, newValue)
            if abs(newHeight - _contentHeight) > 1 && !isUpdatingHeight {
                isUpdatingHeight = true
                _contentHeight = newHeight
                
                DispatchQueue.main.async {
                    self.invalidateIntrinsicContentSize()
                    self.superview?.needsLayout = true
                    self.isUpdatingHeight = false
                }
            }
        }
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: _contentHeight)
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
        
        // Configure scrolling behavior
        webView.enclosingScrollView?.hasVerticalScroller = false
        webView.enclosingScrollView?.hasHorizontalScroller = true
        webView.enclosingScrollView?.verticalScrollElasticity = .none
        webView.enclosingScrollView?.horizontalScrollElasticity = .allowed
        webView.enclosingScrollView?.autohidesScrollers = true
        
        // Set up the coordinator with a reference to the webView
        context.coordinator.webView = webView
        
        return webView
    }
    
    func updateNSView(_ webView: DynamicHeightWebView, context: Context) {
        // Check if we need to update (avoid unnecessary reloads)
        if context.coordinator.lastContent != content {
            print("🔄 Content changed: \(content.count) chars")
            
            let htmlContent = generateHTML()
            print("🔄 Loading HTML content: \(content.count) chars -> \(htmlContent.count) HTML chars")
            
            // Safe HTML loading with fallback
            if htmlContent.isEmpty {
                print("⚠️ Empty HTML content, using fallback")
                webView.loadHTMLString("<p>Content loading...</p>", baseURL: nil)
            } else {
                webView.loadHTMLString(htmlContent, baseURL: nil)
            }
            
            context.coordinator.lastContent = content
        } else {
            print("🔄 Content unchanged, skipping reload")
        }
        
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
            overflow-y: visible;
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
            overflow-y: visible;
            height: auto;
            min-height: auto;
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
                            {left: '$', right: '$', display: false},
                            {left: '\\\\(', right: '\\\\)', display: false},
                            {left: '\\\\[', right: '\\\\]', display: true}
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
        print("🔄 Converting markdown: \(markdown.count) characters")
        if markdown.count < 50 {
            print("🔄 Short content debug: '\(markdown)'")
        }
        
        do {
            // Use the enhanced markdown processing with error handling
            let html = try enhancedMarkdownProcessing(markdown)
            print("📄 Generated HTML: \(html.count) characters")
            return html
        } catch {
            print("❌ Markdown processing error: \(error)")
            // Fallback to safe HTML
            let safeContent = markdown
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "<p>\(safeContent)</p>"
        }
    }
    
    /// Enhanced fallback markdown processing when swift-markdown fails
    private func enhancedMarkdownProcessing(_ markdown: String) throws -> String {
        print("🚀 Enhanced Markdown: Processing \(markdown.count) characters")
        print("🚀 Enhanced Markdown: Raw content: '\(markdown)'")
        
        // Prevent infinite loops with empty or whitespace-only content
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            print("🚀 Enhanced Markdown: Empty content, returning minimal HTML")
            return "<p>&nbsp;</p>"
        }
        
        print("🚀 Enhanced Markdown: Trimmed content: '\(trimmed)'")
        
        // Prevent processing extremely long content that might cause loops
        if markdown.count > 50000 {
            print("🚀 Enhanced Markdown: Content too large, truncating")
            return "<p>Content too large to render</p>"
        }
        
        guard !markdown.isEmpty else {
            return "<p>&nbsp;</p>"
        }
        
        let lines = markdown.components(separatedBy: .newlines)
        var result: [String] = []
        
        var inCodeBlock = false
        var codeBlockLanguage = ""
        var inTable = false
        var tableHeaderProcessed = false
        
        // Process with error handling
        for (index, line) in lines.enumerated() {
            // Safety check to prevent infinite loops
            if index > 10000 {
                print("⚠️ Processing stopped at line \(index) to prevent infinite loop")
                break
            }
            var processedLine = line
            
            // Handle code blocks first (they have priority)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if !inCodeBlock {
                    // Start code block
                    inCodeBlock = true
                    codeBlockLanguage = String(line.trimmingCharacters(in: .whitespaces).dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    processedLine = "<pre><code class=\"language-\(codeBlockLanguage)\">"
                } else {
                    // End code block
                    inCodeBlock = false
                    codeBlockLanguage = ""
                    processedLine = "</code></pre>"
                }
                result.append(processedLine)
                continue
            }
            
            // Don't process anything inside code blocks - preserve exactly as is
            if inCodeBlock {
                // HTML escape the content inside code blocks
                let escapedLine = line
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                result.append(escapedLine)
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
        
        // Close any open code block
        if inCodeBlock {
            result.append("</code></pre>")
            print("🚀 Enhanced Markdown: Closed incomplete code block")
        }
        
        // Close any open table
        if inTable {
            result.append("</tbody></table>")
        }
        
        // Wrap consecutive list items in proper list tags
        let finalHTML = wrapListItems(result.joined(separator: "\n"))
        
        print("🚀 Enhanced Markdown: Generated \(finalHTML.count) chars HTML")
        return finalHTML
    }
    
    private func processInlineFormatting(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = text
        
        // IMPORTANT: Process math expressions FIRST before other formatting
        // This prevents other regex patterns from interfering with LaTeX
        
        // Display math ($$...$$) - preserve exactly as is
        // Use a placeholder to protect math during other processing
        var mathPlaceholders: [String: String] = [:]
        var placeholderIndex = 0
        
        // Handle display math $$...$$
        let displayMathPattern = #"\$\$(.*?)\$\$"#
        if let regex = try? NSRegularExpression(pattern: displayMathPattern, options: .dotMatchesLineSeparators) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() { // Process in reverse to maintain indices
                if let range = Range(match.range, in: result) {
                    let mathContent = String(result[range])
                    let placeholder = "MATHPLACEHOLDER\(placeholderIndex)"
                    mathPlaceholders[placeholder] = mathContent
                    result.replaceSubrange(range, with: placeholder)
                    placeholderIndex += 1
                }
            }
        }
        
        // Handle inline math $...$
        let inlineMathPattern = #"\$([^$\n]+)\$"#
        if let regex = try? NSRegularExpression(pattern: inlineMathPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() { // Process in reverse to maintain indices
                if let range = Range(match.range, in: result) {
                    let mathContent = String(result[range])
                    let placeholder = "MATHPLACEHOLDER\(placeholderIndex)"
                    mathPlaceholders[placeholder] = mathContent
                    result.replaceSubrange(range, with: placeholder)
                    placeholderIndex += 1
                }
            }
        }
        
        // Now process other formatting (bold, italic, etc.)
        // Bold (** or __)
        result = safeRegexReplace(result, pattern: #"\*\*(.*?)\*\*"#, replacement: "<strong>$1</strong>")
        result = safeRegexReplace(result, pattern: #"__(.*?)__"#, replacement: "<strong>$1</strong>")
        
        // Italic (* or _) - but avoid conflicts with math
        result = safeRegexReplace(result, pattern: #"(?<!\$)\*([^*\$]+)\*(?!\$)"#, replacement: "<em>$1</em>")
        result = safeRegexReplace(result, pattern: #"(?<!\$)_([^_\$]+)_(?!\$)"#, replacement: "<em>$1</em>")
        
        // Strikethrough
        result = safeRegexReplace(result, pattern: #"~~(.*?)~~"#, replacement: "<del>$1</del>")
        
        // Inline code
        result = safeRegexReplace(result, pattern: #"`([^`]+)`"#, replacement: "<code>$1</code>")
        
        // Links
        result = safeRegexReplace(result, pattern: #"\[(.*?)\]\((.*?)\)"#, replacement: "<a href=\"$2\">$1</a>")
        
        // Restore math expressions from placeholders
        for (placeholder, mathContent) in mathPlaceholders {
            result = result.replacingOccurrences(of: placeholder, with: mathContent)
        }
        
        return result
    }
    
    private func safeRegexReplace(_ text: String, pattern: String, replacement: String) -> String {
        // Note: replacingOccurrences doesn't actually throw, but we'll keep this for safety
        return text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
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
        private var lastHeight: CGFloat = 0
        private var heightUpdateTimer: Timer?
        var lastContent: String = ""
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading")
            
            // Debounced height calculation after load
            heightUpdateTimer?.invalidate()
            heightUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
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
                
                let newHeight = CGFloat(height)
                
                // Prevent infinite loops by checking if height actually changed significantly
                if abs(newHeight - lastHeight) > 5 {
                    print("📏 WebView content height received: \(height) (was: \(lastHeight))")
                    lastHeight = newHeight
                    
                    DispatchQueue.main.async {
                        if let dynamicWebView = self.webView {
                            dynamicWebView.contentHeight = max(20, newHeight)
                        }
                    }
                }
            }
        }
        
        deinit {
            heightUpdateTimer?.invalidate()
        }
    }
}
