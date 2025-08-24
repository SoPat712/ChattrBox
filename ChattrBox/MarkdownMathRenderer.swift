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
            colorScheme: colorScheme,
            isStreaming: isStreaming
        )
        .frame(minHeight: 20)
    }
}


// Custom WebView that reports its content height and intelligently forwards scroll events
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

// --- THE SOLUTION IS HERE ---
// Override the scrollWheel event handler.
override func scrollWheel(with event: NSEvent) {
    // Check if the scroll event is primarily vertical.
    // We compare the absolute delta values. A larger deltaY means the user is scrolling up/down.
    if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
        
        // This is a vertical scroll.
        // We must pass this event to the next responder in the chain.
        // This allows the parent SwiftUI ScrollView to handle it.
        self.nextResponder?.scrollWheel(with: event)
        
    } else {
        
        // This is a horizontal scroll.
        // Let the WKWebView's internal scroll view handle it as usual
        // to allow for scrolling code blocks and tables.
        super.scrollWheel(with: event)
    }
}
}


struct WebViewRenderer: NSViewRepresentable {
    let content: String
    let fontSize: Double
    let colorScheme: ColorScheme
    let isStreaming: Bool
    
    func makeNSView(context: Context) -> DynamicHeightWebView {
        let configuration = WKWebViewConfiguration()
        
        // Add message handlers
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "heightChanged")
        contentController.add(context.coordinator, name: "copyToClipboard")
        contentController.add(context.coordinator, name: "mathRenderComplete")
        contentController.add(context.coordinator, name: "debug")
        contentController.add(context.coordinator, name: "contentUpdated")
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
        let coordinator = context.coordinator
        let contentChanged = context.coordinator.lastContent != content
        
        // ANTI-FLASHING STRATEGY:
        // 1. For initial load or major changes: full reload
        // 2. For streaming updates: incremental DOM updates via JavaScript
        // 3. Smart change detection to minimize reloads
        
        if contentChanged {
            
            // Check if this is initial load
            if coordinator.lastContent.isEmpty {
                print("🚀 Initial content load")
                let htmlContent = generateHTML()
                webView.loadHTMLString(htmlContent, baseURL: nil)
                coordinator.lastContent = content
                coordinator.isInitialized = true
                return
            }
            
            // Check if this is a major structural change that requires full reload
            if shouldForceReload(oldContent: coordinator.lastContent, newContent: content) {
                print("🔄 Major change detected, full reload required")
                let htmlContent = generateHTML()
                webView.loadHTMLString(htmlContent, baseURL: nil)
                coordinator.lastContent = content
                return
            }
            
            // For streaming updates, use incremental DOM updates
            if isStreaming && coordinator.isInitialized {
                print("📝 Streaming update via DOM manipulation")
                updateContentIncrementally(webView: webView, newContent: content, coordinator: coordinator)
                coordinator.lastContent = content
                return
            }
            
            // For non-streaming content that's significantly different
            if !isStreaming {
                let lengthDiff = abs(content.count - coordinator.lastContent.count)
                let similarityThreshold = min(coordinator.lastContent.count / 4, 100)
                
                if lengthDiff > similarityThreshold {
                    print("🔄 Significant non-streaming change, full reload")
                    let htmlContent = generateHTML()
                    webView.loadHTMLString(htmlContent, baseURL: nil)
                    coordinator.lastContent = content
                    return
                }
            }
            
            // Minor changes - try incremental update
            print("✨ Minor change, attempting incremental update")
            updateContentIncrementally(webView: webView, newContent: content, coordinator: coordinator)
            coordinator.lastContent = content
        }

        coordinator.webView = webView
    }
    
    private func shouldForceReload(oldContent: String, newContent: String) -> Bool {
        // Force reload for major structural changes
        
        // Check for code block changes (these affect syntax highlighting)
        let oldCodeBlocks = oldContent.components(separatedBy: "```").count
        let newCodeBlocks = newContent.components(separatedBy: "```").count
        if oldCodeBlocks != newCodeBlocks {
            return true
        }
        
        // Check for table structure changes
        let oldTableRows = oldContent.components(separatedBy: "|").count
        let newTableRows = newContent.components(separatedBy: "|").count
        if abs(oldTableRows - newTableRows) > 5 {
            return true
        }
        
        // Check for major length changes (more than 50% difference)
        let lengthRatio = Double(newContent.count) / max(Double(oldContent.count), 1.0)
        if lengthRatio > 1.5 || lengthRatio < 0.5 {
            return true
        }
        
        // Check for math block changes
        let oldMathBlocks = oldContent.components(separatedBy: "$$").count
        let newMathBlocks = newContent.components(separatedBy: "$$").count
        if oldMathBlocks != newMathBlocks {
            return true
        }
        
        return false
    }
    
    private func updateContentIncrementally(webView: WKWebView, newContent: String, coordinator: Coordinator) {
        // Convert new content to HTML
        let newHTML = convertMarkdownToHTML(newContent)
        
        // Escape the HTML for JavaScript
        let escapedHTML = newHTML
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        
        // JavaScript to update content without flashing
        let script = """
        (function() {
            try {
                // Prevent observer from firing during our update
                if (window.contentObserver) {
                    window.contentObserver.disconnect();
                }
                
                // Find the main content container
                var contentContainer = document.body;
                
                // Create a temporary container with new content
                var tempDiv = document.createElement('div');
                tempDiv.innerHTML = '\(escapedHTML)';
                
                // Smooth content replacement
                var oldScrollTop = window.pageYOffset;
                
                // Replace content while preserving scroll position
                contentContainer.innerHTML = tempDiv.innerHTML;
                
                // Restore scroll position
                window.scrollTo(0, oldScrollTop);
                
                // Re-initialize content (syntax highlighting, math rendering, etc.)
                if (typeof window.initializeNewContent === 'function') {
                    window.initializeNewContent();
                }
                
                // Reconnect observer
                if (window.contentObserver) {
                    window.contentObserver.observe(document.body, {
                        childList: true,
                        subtree: true,
                        characterData: true
                    });
                }
                
                // Notify about successful update
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.contentUpdated) {
                    window.webkit.messageHandlers.contentUpdated.postMessage({
                        success: true,
                        method: 'incremental'
                    });
                }
                
            } catch (error) {
                console.error('Incremental update failed:', error);
                // Notify about failure so Swift can fall back to full reload
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.contentUpdated) {
                    window.webkit.messageHandlers.contentUpdated.postMessage({
                        success: false,
                        error: error.message,
                        method: 'incremental'
                    });
                }
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("❌ Incremental update failed: \(error)")
                // Fallback to full reload
                DispatchQueue.main.async {
                    let htmlContent = self.generateHTML()
                    webView.loadHTMLString(htmlContent, baseURL: nil)
                }
            }
        }
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
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/\(colorScheme == .dark ? "github-dark" : "github").min.css" crossorigin="anonymous">
    
    <style>
        /* ANTI-FLASHING CSS */
        * {
            transition: none !important;
            animation: none !important;
        }
        
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
            /* Prevent flashing during updates */
            opacity: 1;
        }
        
        /* Prevent layout shifts during content updates */
        .content-updating {
            pointer-events: none;
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
        
        /* Math styling - NO TRANSITIONS */
        .katex {
            font-size: 1em !important;
        }
        
        .katex-display {
            margin: 16px 0 !important;
            text-align: center;
            overflow-x: auto;
            overflow-y: visible;
            padding: 0 !important;
        }
        
        .katex-html {
            vertical-align: baseline;
        }
        
        .katex, .katex-display {
            white-space: nowrap;
        }
        
        /* Code styling */
        .code-block-container {
            position: relative;
            margin: 16px 0;
        }
        
        .code-block-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: \(codeBlockBg);
            border-radius: 8px 8px 0 0;
            padding: 8px 16px;
            font-size: \(fontSize * 0.75)px;
            font-weight: 500;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            opacity: 0.7;
        }
        
        .code-block-language {
            color: \(textColor);
            font-weight: 600;
        }
        
        /* Language-specific colors */
        .language-javascript { color: #f7df1e; }
        .language-typescript { color: #3178c6; }
        .language-python { color: #3776ab; }
        .language-java { color: #ed8b00; }
        .language-swift { color: #fa7343; }
        .language-rust { color: #ce422b; }
        .language-go { color: #00add8; }
        .language-cpp, .language-c++ { color: #00599c; }
        .language-c { color: #a8b9cc; }
        .language-csharp { color: #239120; }
        .language-php { color: #777bb4; }
        .language-ruby { color: #cc342d; }
        .language-html { color: #e34f26; }
        .language-css { color: #1572b6; }
        .language-scss { color: #cf649a; }
        .language-json { color: #000000; }
        .language-xml { color: #e37933; }
        .language-yaml { color: #cb171e; }
        .language-markdown { color: #083fa1; }
        .language-bash, .language-shell { color: #4eaa25; }
        .language-sql { color: #336791; }
        .language-kotlin { color: #7f52ff; }
        .language-dart { color: #0175c2; }
        .language-text { color: \(colorScheme == .dark ? "rgba(255,255,255,0.7)" : "rgba(0,0,0,0.7)"); }
        
        .copy-button {
            background: transparent;
            border: 1px solid \(colorScheme == .dark ? "rgba(255,255,255,0.3)" : "rgba(0,0,0,0.3)");
            color: \(textColor);
            padding: 4px 8px;
            border-radius: 4px;
            font-size: \(fontSize * 0.7)px;
            cursor: pointer;
            /* Only allow hover transitions on buttons */
            transition: background-color 0.2s ease, border-color 0.2s ease;
        }
        
        .copy-button:hover {
            background: \(colorScheme == .dark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)");
            border-color: \(colorScheme == .dark ? "rgba(255,255,255,0.5)" : "rgba(0,0,0,0.5)");
        }
        
        .copy-button.copied {
            background: #28a745;
            border-color: #28a745;
            color: white;
        }
        
        pre {
            background: \(codeBlockBg);
            border-radius: 0 0 8px 8px;
            padding: 16px;
            margin: 0;
            overflow-x: auto;
            font-size: \(fontSize * 0.85)px;
            line-height: 1.4;
        }
        
        .code-block-container:not(.has-header) pre {
            border-radius: 8px;
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
        
        /* Tables */
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
        
        /* Task lists */
        .task-list-item {
            list-style: none;
            margin-left: -20px;
        }
        
        .task-list-item input[type="checkbox"] {
            margin-right: 8px;
        }
        
        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border-radius: 4px;
        }
        
        /* Scrollbar styling */
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
    
    <!-- Load KaTeX JavaScript -->
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/katex.min.js" integrity="sha384-cMkvdD8LoxVzGF/RPUKAcvmm49FQ0oxwDF3BGKtDXcEc+T1b2N+teh/OJfpU0jr6" crossorigin="anonymous"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.22/dist/contrib/auto-render.min.js" integrity="sha384-hCXGrW6PitJEwbkoStFjeJxv+fSOOQKOPbJxSfM6G5sWZjAyWhXiTIIAmQqnlLlh" crossorigin="anonymous"></script>
    
    <!-- Load Highlight.js -->
    <script defer src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js" crossorigin="anonymous"></script>
    
    <script>
        // ANTI-FLASHING JAVASCRIPT
        
        // Global state
        let isKatexLoaded = false;
        let isHighlightLoaded = false;
        let contentInitialized = false;
        let initializationAttempts = 0;
        const MAX_INIT_ATTEMPTS = 10;
        let updateInProgress = false;
        
        // Debug logging
        function debugLog(message) {
            console.log('🔧 MathRenderer: ' + message);
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.debug) {
                try {
                    window.webkit.messageHandlers.debug.postMessage(message);
                } catch (e) {
                    // Silent fail
                }
            }
        }
        
        // MAIN INITIALIZATION - FLASHING-FREE
        function initializeContent() {
            if (updateInProgress) {
                debugLog('⏸️ Update in progress, skipping initialization');
                return;
            }
            
            updateInProgress = true;
            
            try {
                initializationAttempts++;
                debugLog(`Initialization attempt ${initializationAttempts}/${MAX_INIT_ATTEMPTS}`);
                
                if (initializationAttempts > MAX_INIT_ATTEMPTS) {
                    debugLog('❌ Max initialization attempts reached');
                    updateInProgress = false;
                    return;
                }
                
                // Check library availability
                isKatexLoaded = typeof renderMathInElement !== 'undefined';
                isHighlightLoaded = typeof hljs !== 'undefined';
                
                debugLog(`Libraries - KaTeX: ${isKatexLoaded}, Highlight.js: ${isHighlightLoaded}`);
                
                if (!isKatexLoaded || !isHighlightLoaded) {
                    debugLog('⏳ Libraries not ready, retrying...');
                    updateInProgress = false;
                    setTimeout(initializeContent, 200 * Math.min(initializationAttempts, 5));
                    return;
                }
                
                // Initialize content without flashing
                addCodeBlockHeaders();
                highlightCodeBlocks();
                renderMathExpressions();
                wrapTablesForScrolling();
                
                contentInitialized = true;
                debugLog('✅ Initialization completed');
                
                // Update height smoothly
                setTimeout(updateHeight, 100);
                
            } catch (error) {
                debugLog(`❌ Initialization error: ${error.message}`);
                setTimeout(initializeContent, 500);
            } finally {
                updateInProgress = false;
            }
        }
        
        // FLASHING-FREE CONTENT REINITIALIZATION
        window.initializeNewContent = function() {
            if (updateInProgress) return;
            updateInProgress = true;
            
            try {
                debugLog('🔄 Re-initializing content after update');
                
                // Disable observer temporarily
                if (window.contentObserver) {
                    window.contentObserver.disconnect();
                }
                
                // Re-process content
                addCodeBlockHeaders();
                
                if (isHighlightLoaded) {
                    highlightCodeBlocks();
                }
                
                if (isKatexLoaded) {
                    renderMathExpressions();
                }
                
                wrapTablesForScrolling();
                updateHeight();
                
                // Re-enable observer
                setTimeout(() => {
                    if (window.contentObserver) {
                        window.contentObserver.observe(document.body, {
                            childList: true,
                            subtree: true,
                            characterData: true
                        });
                    }
                }, 100);
                
                debugLog('✅ Content re-initialization completed');
                
            } catch (error) {
                debugLog(`❌ Content re-initialization failed: ${error.message}`);
            } finally {
                updateInProgress = false;
            }
        };
        
        // Enhanced math rendering
        function renderMathExpressions() {
            if (!isKatexLoaded) return;
            
            try {
                debugLog('🧮 Rendering math expressions...');
                
                renderMathInElement(document.body, {
                    delimiters: [
                        {left: '$$', right: '$$', display: true},
                        {left: '$', right: '$', display: false},
                        {left: '\\\\(', right: '\\\\)', display: false},
                        {left: '\\\\[', right: '\\\\]', display: true},
                        {left: '\\\\begin{equation}', right: '\\\\end{equation}', display: true},
                        {left: '\\\\begin{align}', right: '\\\\end{align}', display: true},
                        {left: '\\\\begin{alignat}', right: '\\\\end{alignat}', display: true},
                        {left: '\\\\begin{gather}', right: '\\\\end{gather}', display: true},
                        {left: '\\\\begin{CD}', right: '\\\\end{CD}', display: true}
                    ],
                    ignoredTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code', 'option'],
                    errorCallback: function(msg, err) {
                        debugLog(`❌ KaTeX error: ${msg}`);
                    },
                    throwOnError: false,
                    errorColor: '#cc0000',
                    strict: false,
                    trust: false,
                    preProcess: function(math) {
                        return math.trim();
                    }
                });
                
                debugLog('✅ Math rendering completed');
                
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mathRenderComplete) {
                    window.webkit.messageHandlers.mathRenderComplete.postMessage({
                        success: true,
                        mathElementsFound: document.querySelectorAll('.katex').length
                    });
                }
                
            } catch (error) {
                debugLog(`❌ Math rendering failed: ${error.message}`);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mathRenderComplete) {
                    window.webkit.messageHandlers.mathRenderComplete.postMessage({
                        success: false,
                        error: error.message
                    });
                }
            }
        }
        
        // Code highlighting
        function highlightCodeBlocks() {
            if (!isHighlightLoaded) return;
            
            try {
                debugLog('🎨 Highlighting code blocks...');
                hljs.highlightAll();
                const codeBlocks = document.querySelectorAll('pre code');
                debugLog(`✅ Highlighted ${codeBlocks.length} code blocks`);
            } catch (error) {
                debugLog(`❌ Code highlighting failed: ${error.message}`);
            }
        }
        
        // Table wrapping
        function wrapTablesForScrolling() {
            try {
                const tables = document.querySelectorAll('table:not(.table-container table)');
                tables.forEach((table, index) => {
                    if (!table.closest('.table-container')) {
                        const wrapper = document.createElement('div');
                        wrapper.className = 'table-container';
                        table.parentNode.insertBefore(wrapper, table);
                        wrapper.appendChild(table);
                    }
                });
            } catch (error) {
                debugLog(`❌ Table wrapping failed: ${error.message}`);
            }
        }
        
        // Height calculation without flashing
        function updateHeight() {
            try {
                requestAnimationFrame(() => {
                    requestAnimationFrame(() => {
                        const height = Math.max(
                            document.body.scrollHeight,
                            document.body.offsetHeight,
                            document.documentElement.scrollHeight,
                            document.documentElement.offsetHeight,
                            20
                        );
                        
                        debugLog(`📏 Height: ${height}px`);
                        
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChanged) {
                            window.webkit.messageHandlers.heightChanged.postMessage({ height: height });
                        }
                    });
                });
            } catch (error) {
                debugLog(`❌ Height update failed: ${error.message}`);
            }
        }
        
        // Code block headers
        function addCodeBlockHeaders() {
            try {
                const codeBlocks = document.querySelectorAll('pre code:not(.has-header)');
                
                codeBlocks.forEach((codeElement, index) => {
                    const preElement = codeElement.parentElement;
                    
                    if (preElement.parentElement.classList.contains('code-block-container')) {
                        return;
                    }
                    
                    // Extract language
                    let language = 'text';
                    const classNames = codeElement.className.split(' ');
                    for (const className of classNames) {
                        if (className.startsWith('language-')) {
                            language = className.replace('language-', '');
                            break;
                        }
                    }
                    
                    // Create container and header
                    const container = document.createElement('div');
                    container.className = 'code-block-container has-header';
                    
                    const header = document.createElement('div');
                    header.className = 'code-block-header';
                    
                    const languageLabel = document.createElement('span');
                    languageLabel.className = `code-block-language language-${language}`;
                    languageLabel.textContent = language.toUpperCase();
                    
                    const copyButton = document.createElement('button');
                    copyButton.className = 'copy-button';
                    copyButton.textContent = 'COPY';
                    copyButton.onclick = function() {
                        copyCodeToClipboard(codeElement, copyButton);
                    };
                    
                    header.appendChild(languageLabel);
                    header.appendChild(copyButton);
                    
                    // Wrap the pre element
                    preElement.parentNode.insertBefore(container, preElement);
                    container.appendChild(header);
                    container.appendChild(preElement);
                    
                    // Mark as processed
                    codeElement.classList.add('has-header');
                });
                
            } catch (error) {
                debugLog(`❌ Adding code headers failed: ${error.message}`);
            }
        }
        
        // Copy functionality
        function copyCodeToClipboard(codeElement, button) {
            const text = codeElement.textContent || codeElement.innerText;
            debugLog(`📋 Copying ${text.length} characters`);
            
            window.currentCopyButton = button;
            
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.copyToClipboard) {
                window.webkit.messageHandlers.copyToClipboard.postMessage(text);
            } else {
                fallbackCopyToClipboard(text, button);
            }
        }
        
        function fallbackCopyToClipboard(text, button) {
            try {
                const tempElement = document.createElement('div');
                tempElement.style.position = 'absolute';
                tempElement.style.left = '-9999px';
                tempElement.style.whiteSpace = 'pre';
                tempElement.textContent = text;
                
                document.body.appendChild(tempElement);
                
                const range = document.createRange();
                range.selectNodeContents(tempElement);
                const selection = window.getSelection();
                selection.removeAllRanges();
                selection.addRange(range);
                
                const successful = document.execCommand('copy');
                selection.removeAllRanges();
                document.body.removeChild(tempElement);
                
                if (successful) {
                    showCopySuccess(button);
                } else {
                    throw new Error('Copy command failed');
                }
            } catch (err) {
                debugLog(`❌ Fallback copy failed: ${err.message}`);
                showCopyError(button);
            }
        }
        
        function showCopySuccess(button) {
            button.textContent = 'COPIED';
            button.classList.add('copied');
            setTimeout(() => {
                button.textContent = 'COPY';
                button.classList.remove('copied');
            }, 2000);
        }
        
        function showCopyError(button) {
            button.textContent = 'FAILED';
            button.style.background = '#dc3545';
            button.style.borderColor = '#dc3545';
            button.style.color = 'white';
            
            setTimeout(() => {
                button.textContent = 'COPY';
                button.classList.remove('copied');
                button.style.background = '';
                button.style.borderColor = '';
                button.style.color = '';
            }, 2000);
        }
        
        // Swift callback functions
        window.copySuccess = function() {
            if (window.currentCopyButton) {
                showCopySuccess(window.currentCopyButton);
                window.currentCopyButton = null;
            }
        };
        
        window.copyFailed = function() {
            if (window.currentCopyButton) {
                showCopyError(window.currentCopyButton);
                window.currentCopyButton = null;
            }
        };
        
        // ANTI-FLASHING CONTENT OBSERVER
        let updateTimeout;
        window.contentObserver = new MutationObserver(function(mutations) {
            // Only react to changes if we're not in the middle of an update
            if (!updateInProgress && contentInitialized) {
                clearTimeout(updateTimeout);
                updateTimeout = setTimeout(function() {
                    debugLog('🔄 Content mutation detected, re-initializing...');
                    window.initializeNewContent();
                }, 200); // Longer debounce to prevent flashing
            }
        });
        
        // INITIALIZATION TRIGGERS - MULTIPLE FALLBACKS
        
        // 1. Immediate check
        if (document.readyState === 'complete') {
            debugLog('📄 Document ready, initializing immediately');
            setTimeout(initializeContent, 10);
        }
        
        // 2. DOM Content Loaded
        document.addEventListener('DOMContentLoaded', function() {
            debugLog('📄 DOM Content Loaded');
            setTimeout(initializeContent, 10);
        });
        
        // 3. Window load
        window.addEventListener('load', function() {
            debugLog('📄 Window loaded');
            setTimeout(initializeContent, 10);
        });
        
        // 4. Library detection intervals
        let katexCheckCount = 0;
        const katexInterval = setInterval(function() {
            katexCheckCount++;
            if (typeof renderMathInElement !== 'undefined') {
                debugLog('✅ KaTeX detected');
                clearInterval(katexInterval);
                if (typeof hljs !== 'undefined' && !contentInitialized) {
                    setTimeout(initializeContent, 10);
                }
            } else if (katexCheckCount >= 50) { // 5 seconds
                debugLog('⚠️ KaTeX timeout');
                clearInterval(katexInterval);
            }
        }, 100);
        
        let hlJSCheckCount = 0;
        const hlJSInterval = setInterval(function() {
            hlJSCheckCount++;
            if (typeof hljs !== 'undefined') {
                debugLog('✅ Highlight.js detected');
                clearInterval(hlJSInterval);
                if (typeof renderMathInElement !== 'undefined' && !contentInitialized) {
                    setTimeout(initializeContent, 10);
                }
            } else if (hlJSCheckCount >= 50) { // 5 seconds
                debugLog('⚠️ Highlight.js timeout');
                clearInterval(hlJSInterval);
            }
        }, 100);
        
        // 5. Fallback initialization
        setTimeout(function() {
            if (!contentInitialized) {
                debugLog('⏰ Fallback initialization');
                initializeContent();
            }
        }, 2000);
        
        // 6. Start content observer after initial setup
        setTimeout(function() {
            if (window.contentObserver) {
                window.contentObserver.observe(document.body, {
                    childList: true,
                    subtree: true,
                    characterData: true
                });
                debugLog('👁️ Content observer started');
            }
        }, 1000);
        
    </script>
</body>
</html>
"""
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "<p>&nbsp;</p>"
        }
        
        do {
            let html = try enhancedMarkdownProcessing(markdown)
            return html
        } catch {
            print("❌ Markdown processing error: \(error)")
            let safeContent = markdown
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return "<p>\(safeContent)</p>"
        }
    }
    
    /// Enhanced markdown processing with better math handling
    private func enhancedMarkdownProcessing(_ markdown: String) throws -> String {
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "<p>&nbsp;</p>"
        }
        
        // Prevent processing extremely long content
        if markdown.count > 50000 {
            return "<p>Content too large to render</p>"
        }
        
        let lines = markdown.components(separatedBy: .newlines)
        var result: [String] = []
        
        var inCodeBlock = false
        var codeBlockLanguage = ""
        var codeBlockContent: [String] = [] // Buffer to hold lines of code
        
        var inTable = false
        var tableHeaderProcessed = false
        
        for (index, line) in lines.enumerated() {
            if index > 10000 { break } // Safety check
            
            // Handle code blocks (highest priority)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if !inCodeBlock {
                    // --- START of a code block ---
                    inCodeBlock = true
                    codeBlockLanguage = String(line.trimmingCharacters(in: .whitespaces).dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeBlockContent = [] // Clear the buffer
                } else {
                    // --- END of a code block ---
                    inCodeBlock = false
                    
                    // Escape the collected content
                    let escapedContent = codeBlockContent.joined(separator: "\n")
                        .replacingOccurrences(of: "&", with: "&amp;")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                    
                    // Construct the full HTML for the code block
                    let codeHTML = "<pre><code class=\"language-\(codeBlockLanguage)\">\(escapedContent)</code></pre>"
                    result.append(codeHTML)
                }
                continue // Move to the next line
            }
            
            // If we are inside a code block, just add the line to our buffer
            if inCodeBlock {
                codeBlockContent.append(line)
                continue
            }
            
            // --- All other processing below this line is for non-code content ---
            
            var processedLine = line
            
            // Handle tables (GitHub Flavored Markdown style)
            if line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !inTable {
                    inTable = true
                    tableHeaderProcessed = false
                    result.append("<table>")
                }
                
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Check if this is a separator line (|---|---|)
                let isSeparator = trimmed.replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "|", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: ":", with: "").isEmpty
                
                if isSeparator && !tableHeaderProcessed {
                    result.append("</thead><tbody>")
                    tableHeaderProcessed = true
                } else if !isSeparator {
                    let cells = trimmed.components(separatedBy: "|")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    
                    if !tableHeaderProcessed {
                        result.append("<thead><tr>")
                        for cell in cells {
                            result.append("<th>\(processInlineFormatting(cell))</th>")
                        }
                        result.append("</tr>")
                    } else {
                        result.append("<tr>")
                        for cell in cells {
                            result.append("<td>\(processInlineFormatting(cell))</td>")
                        }
                        result.append("</tr>")
                    }
                }
                continue
            } else if inTable {
                result.append("</tbody></table>")
                inTable = false
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
            else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                processedLine = "<hr>"
            }
            // Blockquote
            else if trimmed.hasPrefix(">") {
                processedLine = "<blockquote>\(processInlineFormatting(String(trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces))))</blockquote>"
            }
            // Task lists
            else if trimmed.hasPrefix("- [ ] ") {
                let content = String(trimmed.dropFirst(6))
                processedLine = "<li class=\"task-list-item\"><input type=\"checkbox\" disabled> \(processInlineFormatting(content))</li>"
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let content = String(trimmed.dropFirst(6))
                processedLine = "<li class=\"task-list-item\"><input type=\"checkbox\" checked disabled> \(processInlineFormatting(content))</li>"
            }
            // Unordered list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let content = String(trimmed.dropFirst(2))
                processedLine = "<li>\(processInlineFormatting(content))</li>"
            }
            // Ordered list
            else if let match = trimmed.range(of: #"^\d+\. "#, options: .regularExpression) {
                let content = String(trimmed[match.upperBound...])
                processedLine = "<li>\(processInlineFormatting(content))</li>"
            }
            // Regular paragraph
            else {
                processedLine = "<p>\(processInlineFormatting(trimmed))</p>"
            }
            
            result.append(processedLine)
        }
        
        // Close any open structures
        if inCodeBlock {
            // This handles an unclosed code block at the end of the file
            let escapedContent = codeBlockContent.joined(separator: "\n")
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            let codeHTML = "<pre><code class=\"language-\(codeBlockLanguage)\">\(escapedContent)</code></pre>"
            result.append(codeHTML)
        }
        
        if inTable {
            result.append("</tbody></table>")
        }
        
        // Wrap consecutive list items in proper list tags
        let finalHTML = wrapListItems(result.joined(separator: "\n"))
        
        return finalHTML
    }
    /// Process inline formatting with enhanced math handling
    private func processInlineFormatting(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = text
        
        // CRITICAL: Process math expressions FIRST to protect them from other formatting
        var mathPlaceholders: [String: String] = [:]
        var placeholderIndex = 0
        
        // Protect display math $...$
        let displayMathPattern = #"\$\$((?:[^$]|\$(?!\$))*)\$\$"#
        if let regex = try? NSRegularExpression(pattern: displayMathPattern, options: .dotMatchesLineSeparators) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let mathContent = String(result[range])
                    let placeholder = "MATHPLACEHOLDER\(placeholderIndex)"
                    mathPlaceholders[placeholder] = mathContent
                    result.replaceSubrange(range, with: placeholder)
                    placeholderIndex += 1
                }
            }
        }
        
        // Protect inline math $...$
        let inlineMathPattern = #"\$([^$\n]*(?:\$[^$\n]*)*[^$\n]*)\$"#
        if let regex = try? NSRegularExpression(pattern: inlineMathPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let mathContent = String(result[range])
                    // Additional validation to avoid false matches
                    if isValidMathExpression(mathContent) {
                        let placeholder = "MATHPLACEHOLDER\(placeholderIndex)"
                        mathPlaceholders[placeholder] = mathContent
                        result.replaceSubrange(range, with: placeholder)
                        placeholderIndex += 1
                    }
                }
            }
        }
        
        // Protect LaTeX environments
        let latexEnvPattern = #"\\begin\{[^}]+\}.*?\\end\{[^}]+\}"#
        if let regex = try? NSRegularExpression(pattern: latexEnvPattern, options: .dotMatchesLineSeparators) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let mathContent = String(result[range])
                    let placeholder = "MATHPLACEHOLDER\(placeholderIndex)"
                    mathPlaceholders[placeholder] = mathContent
                    result.replaceSubrange(range, with: placeholder)
                    placeholderIndex += 1
                }
            }
        }
        
        // Now process other inline formatting
        
        // Bold (** or __)
        result = safeRegexReplace(result, pattern: #"\*\*((?:[^*]|\*(?!\*))*)\*\*"#, replacement: "<strong>$1</strong>")
        result = safeRegexReplace(result, pattern: #"__((?:[^_]|_(?!_))*)__"#, replacement: "<strong>$1</strong>")
        
        // Italic (* or _) - with improved patterns to avoid math conflicts
        result = safeRegexReplace(result, pattern: #"(?<!\*)\*([^*\s][^*]*[^*\s]|\S)\*(?!\*)"#, replacement: "<em>$1</em>")
        result = safeRegexReplace(result, pattern: #"(?<!_)_([^_\s][^_]*[^_\s]|\S)_(?!_)"#, replacement: "<em>$1</em>")
        
        // Strikethrough
        result = safeRegexReplace(result, pattern: #"~~([^~]+)~~"#, replacement: "<del>$1</del>")
        
        // Inline code (protect from math)
        result = safeRegexReplace(result, pattern: #"`([^`]+)`"#, replacement: "<code>$1</code>")
        
        // Links [text](url)
        result = safeRegexReplace(result, pattern: #"\[([^\]]*)\]\(([^)]+)\)"#, replacement: "<a href=\"$2\">$1</a>")
        
        // Auto-links <url>
        result = safeRegexReplace(result, pattern: #"<(https?://[^>]+)>"#, replacement: "<a href=\"$1\">$1</a>")
        
        // Restore math expressions from placeholders
        for (placeholder, mathContent) in mathPlaceholders {
            result = result.replacingOccurrences(of: placeholder, with: mathContent)
        }
        
        return result
    }
    
    /// Validate that a potential math expression is actually valid
    private func isValidMathExpression(_ expr: String) -> Bool {
        // Remove outer $ symbols
        let inner = expr.dropFirst().dropLast()
        
        // Must not be empty
        if inner.isEmpty { return false }
        
        // Must not be just whitespace
        if inner.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        
        // Should contain mathematical content (numbers, operators, letters, or LaTeX commands)
        let mathPattern = #"[0-9+\-*/=<>{}()\\a-zA-Z\s,.;:|^_]"#
        let hasValidChars = inner.range(of: mathPattern, options: .regularExpression) != nil
        
        return hasValidChars
    }
    
    /// Safe regex replacement with error handling
    private func safeRegexReplace(_ text: String, pattern: String, replacement: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
        } catch {
            // If regex fails, return original text
            return text
        }
    }
    
    /// Wrap consecutive list items in proper ul/ol tags
    private func wrapListItems(_ html: String) -> String {
        var result = html
        
        // Wrap unordered lists
        let ulPattern = #"(<li(?:\s+class="[^"]*")?>[^<]*</li>(?:\s*<li(?:\s+class="[^"]*")?>[^<]*</li>)*)"#
        result = safeRegexReplace(result, pattern: ulPattern, replacement: "<ul>$1</ul>")
        
        // Clean up consecutive ul tags
        result = safeRegexReplace(result, pattern: #"</ul>\s*<ul>"#, replacement: "")
        
        return result
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: DynamicHeightWebView?
        private var lastHeight: CGFloat = 0
        private var heightUpdateTimer: Timer?
        var lastContent: String = ""
        var isInitialized: Bool = false
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading")
            
            // Debounced height calculation after load
            heightUpdateTimer?.invalidate()
            heightUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                webView.evaluateJavaScript("updateHeight();") { _, error in
                    if let error = error {
                        print("❌ Height update script error: \(error)")
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView failed to load: \(error)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView provisional load failed: \(error)")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "heightChanged":
                if let body = message.body as? [String: Any],
                   let height = body["height"] as? Double {
                    
                    let newHeight = CGFloat(height)
                    
                    if abs(newHeight - lastHeight) > 5 {
                        print("📏 WebView height: \(height) (was: \(lastHeight))")
                        lastHeight = newHeight
                        
                        DispatchQueue.main.async {
                            if let dynamicWebView = self.webView {
                                dynamicWebView.contentHeight = max(20, newHeight)
                            }
                        }
                    }
                }
                
            case "copyToClipboard":
                if let text = message.body as? String {
                    print("📋 Copying to clipboard: \(text.prefix(50))...")
                    
                    DispatchQueue.main.async {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        let success = pasteboard.setString(text, forType: .string)
                        
                        let script = success ?
                            "window.copySuccess && window.copySuccess();" :
                            "window.copyFailed && window.copyFailed();"
                        
                        self.webView?.evaluateJavaScript(script) { _, error in
                            if let error = error {
                                print("❌ Copy callback error: \(error)")
                            }
                        }
                    }
                }
                
            case "mathRenderComplete":
                if let body = message.body as? [String: Any] {
                    let success = body["success"] as? Bool ?? false
                    let mathCount = body["mathElementsFound"] as? Int ?? 0
                    print("🧮 Math rendering \(success ? "completed" : "failed"): \(mathCount) elements")
                    
                    if let error = body["error"] as? String {
                        print("❌ Math render error: \(error)")
                    }
                }
                
            case "contentUpdated":
                if let body = message.body as? [String: Any] {
                    let success = body["success"] as? Bool ?? false
                    let method = body["method"] as? String ?? "unknown"
                    
                    if success {
                        print("✅ Content updated successfully via \(method)")
                    } else {
                        print("❌ Content update failed via \(method)")
                        if let error = body["error"] as? String {
                            print("❌ Update error: \(error)")
                        }
                        
                        // Fallback to full reload on incremental update failure
                        if method == "incremental" {
                            print("🔄 Falling back to full reload")
                            // The webView will automatically trigger a full reload
                        }
                    }
                }
                
            case "debug":
                if let debugMessage = message.body as? String {
                    print("🔧 JS Debug: \(debugMessage)")
                }
                
            default:
                print("⚠️ Unknown message: \(message.name)")
            }
        }
        
        deinit {
            heightUpdateTimer?.invalidate()
        }
    }
}
