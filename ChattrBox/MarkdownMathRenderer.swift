import SwiftUI
import WebKit
import Down

struct MarkdownMathRenderer: View {
    let content: String
    let fontSize: Double
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        // Simple text renderer - REMOVE FIRST 2 LINES to eliminate empty space
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        Text(trimmedContent)
            .font(.system(size: fontSize))
            .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0d0d0d"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }
}

struct DownMathJaxWebView: NSViewRepresentable {
    let content: String
    let fontSize: Double
    let colorScheme: ColorScheme
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Configure web view appearance for transparency
        webView.setValue(false, forKey: "drawsBackground")
        
        // Disable scrolling
        webView.enclosingScrollView?.hasVerticalScroller = false
        webView.enclosingScrollView?.hasHorizontalScroller = false
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let htmlContent = generateHTML()
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func generateHTML() -> String {
        // Convert markdown to HTML using Down
        let markdownHTML: String
        do {
            let down = Down(markdownString: content)
            // Use safe mode to prevent XSS but allow standard markdown
            markdownHTML = try down.toHTML(.safe)
        } catch {
            // Fallback: escape HTML and convert line breaks
            let escaped = content
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\n", with: "<br>")
            markdownHTML = "<p>\(escaped)</p>"
        }
        
        let textColor = colorScheme == .dark ? "#FFFFFF" : "#0d0d0d"
        let codeBlockBg = colorScheme == .dark ? "rgba(0,0,0,0.3)" : "rgba(0,0,0,0.1)"
        let inlineCodeBg = colorScheme == .dark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)"
        let tableBorder = colorScheme == .dark ? "rgba(255,255,255,0.2)" : "rgba(0,0,0,0.2)"
        let tableHeaderBg = colorScheme == .dark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)"
        let tableRowBg = colorScheme == .dark ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.05)"
        let blockquoteBorder = colorScheme == .dark ? "rgba(255,255,255,0.3)" : "rgba(0,0,0,0.3)"
        let blockquoteColor = colorScheme == .dark ? "rgba(255,255,255,0.8)" : "rgba(0,0,0,0.7)"
        let hrColor = colorScheme == .dark ? "rgba(255,255,255,0.2)" : "rgba(0,0,0,0.2)"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            
            <!-- MathJax Configuration -->
            <script>
                window.MathJax = {
                    tex: {
                        inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                        displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
                        processEscapes: true,
                        processEnvironments: true,
                        tags: 'none'
                    },
                    svg: {
                        fontCache: 'global',
                        scale: 1,
                        minScale: 0.5,
                        matchFontHeight: false
                    },
                    startup: {
                        ready: () => {
                            MathJax.startup.defaultReady();
                            // Auto-size after rendering
                            MathJax.startup.promise.then(() => {
                                document.body.style.height = 'auto';
                                const height = Math.max(document.body.scrollHeight, document.body.offsetHeight);
                                document.body.style.height = height + 'px';
                            });
                        }
                    }
                };
            </script>
            
            <!-- Load MathJax from CDN -->
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"></script>
            
            <style>
                * {
                    box-sizing: border-box;
                }
                
                html, body {
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: \(fontSize)px;
                    line-height: 1.5;
                    color: \(textColor);
                    background: transparent;
                    overflow: hidden;
                }
                
                body {
                    padding: 0;
                    margin: 0;
                    min-height: 100%;
                }
                
                /* Reset margins for consistent spacing */
                p, h1, h2, h3, h4, h5, h6, ul, ol, blockquote, pre {
                    margin-top: 0;
                    margin-bottom: 12px;
                }
                
                p:last-child, h1:last-child, h2:last-child, h3:last-child, 
                h4:last-child, h5:last-child, h6:last-child, ul:last-child, 
                ol:last-child, blockquote:last-child, pre:last-child {
                    margin-bottom: 0;
                }
                
                /* Headers */
                h1, h2, h3, h4, h5, h6 {
                    font-weight: 600;
                    line-height: 1.3;
                    margin-bottom: 8px;
                }
                
                h1 { font-size: \(fontSize + 8)px; }
                h2 { font-size: \(fontSize + 6)px; }
                h3 { font-size: \(fontSize + 4)px; }
                h4 { font-size: \(fontSize + 2)px; }
                h5 { font-size: \(fontSize)px; }
                h6 { font-size: \(max(fontSize - 2, 10))px; }
                
                /* Code blocks */
                pre {
                    background-color: \(codeBlockBg);
                    border-radius: 8px;
                    padding: 12px;
                    overflow-x: auto;
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
                    font-size: \(max(fontSize - 2, 10))px;
                    white-space: pre-wrap;
                }
                
                /* Inline code */
                code {
                    font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
                    font-size: \(max(fontSize - 2, 10))px;
                    background-color: \(inlineCodeBg);
                    padding: 2px 4px;
                    border-radius: 4px;
                }
                
                pre code {
                    background: none;
                    padding: 0;
                    font-size: inherit;
                }
                
                /* Lists */
                ul, ol {
                    padding-left: 20px;
                    margin-bottom: 8px;
                }
                
                li {
                    margin: 2px 0;
                }
                
                /* Tables */
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 8px 0;
                    font-size: \(max(fontSize - 1, 10))px;
                }
                
                th, td {
                    border: 1px solid \(tableBorder);
                    padding: 8px;
                    text-align: left;
                }
                
                th {
                    background-color: \(tableHeaderBg);
                    font-weight: 600;
                }
                
                tr:nth-child(even) {
                    background-color: \(tableRowBg);
                }
                
                /* Blockquotes */
                blockquote {
                    border-left: 4px solid \(blockquoteBorder);
                    margin: 8px 0;
                    padding-left: 16px;
                    color: \(blockquoteColor);
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
                
                /* Horizontal rule */
                hr {
                    border: none;
                    border-top: 1px solid \(hrColor);
                    margin: 16px 0;
                }
                
                /* Images */
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 4px;
                }
                
                /* MathJax styling */
                .MathJax {
                    outline: none;
                    display: inline-block;
                    vertical-align: middle;
                }
                
                .MathJax_Display {
                    margin: 16px 0;
                    text-align: center;
                    display: block;
                }
                
                /* Strong and emphasis */
                strong, b {
                    font-weight: 600;
                }
                
                em, i {
                    font-style: italic;
                }
                
                /* Text selection */
                ::selection {
                    background-color: rgba(0, 122, 255, 0.3);
                }
            </style>
        </head>
        <body>
            \(markdownHTML)
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Content loaded successfully
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow only the main frame to load
            if navigationAction.navigationType == .other && navigationAction.targetFrame?.isMainFrame == true {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        }
    }
}