import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct SimpleChatBubble: View {
    let message: ChatMessage
    let onRegenerate: (() -> Void)?
    let onVersionChange: ((Int) -> Void)?
    let fontSize: Double
    let showCursor: Bool
    @State private var showButtons = false
    @Environment(\.colorScheme) var colorScheme
    
    init(message: ChatMessage, onRegenerate: (() -> Void)? = nil, onVersionChange: ((Int) -> Void)? = nil, fontSize: Double = 14.0, showCursor: Bool = false) {
        self.message = message
        self.onRegenerate = onRegenerate
        self.onVersionChange = onVersionChange
        self.fontSize = fontSize
        self.showCursor = showCursor
    }
    
    private var backgroundColor: Color {
        if message.isUser {
            return Color.blue.opacity(0.6)
        } else {
            // AI messages should have a subtle background that respects transparency
            return colorScheme == .dark ?
                Color.white.opacity(0.15) :
                Color.black.opacity(0.08)
        }
    }
    
    private var textColor: Color {
        if message.isUser {
            return .white
        } else {
            return colorScheme == .dark ? .white : Color(hex: "0d0d0d")
        }
    }
    
    var body: some View {
        HStack(alignment: .top) {
            if message.isUser {
                Spacer(minLength: 40) // Allow room for expansion but provide right alignment
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    // Message content
                    if message.isUser {
                        // User messages - simple text
                        Text(message.displayContent)
                            .font(.system(size: fontSize))
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(backgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(textColor)
                    } else {
                        // AI messages - hybrid rendering: stable rendered content + raw streaming
                        VStack(spacing: 0) {
                            if showCursor {
                                // Streaming mode: show rendered content above + raw streaming below
                                StreamingContentView(
                                    content: message.displayContent,
                                    fontSize: fontSize,
                                    textColor: textColor
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            } else {
                                // Static mode: show fully rendered content
                                HStack(alignment: .top, spacing: 0) {
                                    MarkdownMathRenderer(
                                        content: message.displayContent.isEmpty ? " " : message.displayContent,
                                        fontSize: fontSize,
                                        isStreaming: false
                                    )
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(backgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1.0)
                                )
                        )
                        .foregroundColor(textColor)
                    }
                    
                    // Action buttons - version navigation and actions
                    if showButtons {
                        HStack(spacing: 1) {
                            if message.isUser {
                                // User message: Copy button only
                                Button(action: copyMessage) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .gray.opacity(0.8))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .help("Copy message")
                            } else {
                                // AI message: Version navigation and actions
                                
                                // Left arrow (previous version)
                                Button(action: {
                                    let newIndex = max(0, message.currentVersionIndex - 1)
                                    onVersionChange?(newIndex)
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(message.currentVersionIndex > 0 ?
                                            (colorScheme == .dark ? .white.opacity(0.9) : .gray.opacity(0.8)) :
                                            (colorScheme == .dark ? .white.opacity(0.3) : .gray.opacity(0.3)))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .disabled(message.currentVersionIndex <= 0)
                                .help("Previous version")
                                
                                // Separator
                                Rectangle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                                    .frame(width: 0.5, height: 16)
                                
                                // Version indicator
                                Text("\(message.currentVersionIndex + 1) of \(message.versionCount)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .gray.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 6)
                                
                                // Separator
                                Rectangle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                                    .frame(width: 0.5, height: 16)
                                
                                // Right arrow (next version)
                                Button(action: {
                                    let newIndex = min(message.versionCount - 1, message.currentVersionIndex + 1)
                                    onVersionChange?(newIndex)
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(message.currentVersionIndex < message.versionCount - 1 ?
                                            (colorScheme == .dark ? .white.opacity(0.9) : .gray.opacity(0.8)) :
                                            (colorScheme == .dark ? .white.opacity(0.3) : .gray.opacity(0.3)))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .disabled(message.currentVersionIndex >= message.versionCount - 1)
                                .help("Next version")
                                
                                // Separator
                                Rectangle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                                    .frame(width: 0.5, height: 16)
                                
                                // Regenerate button
                                if onRegenerate != nil {
                                    Button(action: { onRegenerate?() }) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .gray.opacity(0.8))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Regenerate response")
                                    
                                    // Separator
                                    Rectangle()
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                                        .frame(width: 0.5, height: 16)
                                }
                                
                                // Copy button
                                Button(action: copyMessage) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .gray.opacity(0.8))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .help("Copy message")
                            }
                        }
                        .background(
                            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                        .offset(x: 6, y: 6) // Always bottom-right for ALL messages
                        .zIndex(100) // Ensure buttons are always on top
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showButtons = hovering
                    }
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            if !message.isUser {
                Spacer(minLength: 40) // Allow room for expansion but provide left alignment
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message.id)
    }
    
    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.displayContent, forType: .string)
    }
}

// MARK: - Streaming Content View
struct StreamingContentView: View {
    let content: String
    let fontSize: Double
    let textColor: Color
    
    @State private var stableContent: String = ""
    @State private var streamingContent: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Rendered stable content (all complete lines above the current streaming line)
            if !stableContent.isEmpty {
                MarkdownMathRenderer(
                    content: stableContent,
                    fontSize: fontSize,
                    isStreaming: false
                )
                .allowsHitTesting(false)
            }
            
            // Raw streaming content (the current incomplete line being typed)
            if !streamingContent.isEmpty {
                Text(streamingContent)
                    .font(.system(size: fontSize))
                    .foregroundColor(textColor)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
            }
        }
        .onChange(of: content) { _, newValue in
            updateContentSplit(newValue)
        }
        .onAppear {
            updateContentSplit(content)
        }
    }
    
    private func updateContentSplit(_ fullContent: String) {
        // Use a more sophisticated approach to split content that's math-aware
        let (stable, streaming) = splitContentForStreaming(fullContent)
        stableContent = stable
        streamingContent = streaming
    }
    
    private func splitContentForStreaming(_ fullContent: String) -> (stable: String, streaming: String) {
        // If content is very short, keep it all as streaming
        if fullContent.count < 50 {
            return ("", fullContent)
        }
        
        let lines = fullContent.components(separatedBy: .newlines)
        
        // If only one line, check if we can split by sentences
        if lines.count <= 1 {
            return splitBySentences(fullContent)
        }
        
        // Multi-line content: find the best split point
        var stableLines: [String] = []
        var streamingLines: [String] = []
        
        for (index, line) in lines.enumerated() {
            if index == lines.count - 1 {
                // Always keep the last line as streaming unless it's clearly complete
                if isLineDefinitelyComplete(line) && lines.count > 2 {
                    stableLines.append(line)
                } else {
                    streamingLines.append(line)
                }
            } else if isLineSafeToRender(line, nextLine: index < lines.count - 1 ? lines[index + 1] : nil) {
                // Check if this line is complete and safe to render
                stableLines.append(line)
            } else {
                // This line is incomplete or unsafe, everything from here is streaming
                streamingLines = Array(lines[index...])
                break
            }
        }
        
        let stable = stableLines.joined(separator: "\n")
        let streaming = streamingLines.joined(separator: "\n")
        
        // If we have no stable content but content is long, try sentence-based splitting
        if stable.isEmpty && fullContent.count > 150 {
            return splitBySentences(fullContent)
        }
        
        return (stable, streaming)
    }
    
    private func splitBySentences(_ content: String) -> (stable: String, streaming: String) {
        // Split by sentence-ending punctuation, but be careful with math
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        if sentences.count <= 2 {
            return ("", content)
        }
        
        // Keep all but the last 1-2 sentences as stable
        let stableSentenceCount = max(0, sentences.count - 2)
        let stableSentences = Array(sentences.prefix(stableSentenceCount))
        let streamingSentences = Array(sentences.suffix(sentences.count - stableSentenceCount))
        
        var stable = stableSentences.joined(separator: ". ")
        if !stable.isEmpty && !stable.hasSuffix(".") {
            stable += "."
        }
        
        let streaming = streamingSentences.joined(separator: ". ")
        
        // Make sure we don't split in the middle of math expressions
        if containsIncompleteMath(stable) || containsIncompleteMath(streaming) {
            return ("", content)
        }
        
        return (stable, streaming)
    }
    
    private func isLineSafeToRender(_ line: String, nextLine: String?) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Empty lines are always safe
        if trimmed.isEmpty {
            return true
        }
        
        // Check for incomplete math expressions
        if containsIncompleteMath(line) {
            return false
        }
        
        // Check for markdown structures that might be incomplete
        if isIncompleteMarkdownStructure(line, nextLine: nextLine) {
            return false
        }
        
        // Lines that end with clear punctuation are usually safe
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") ||
           trimmed.hasSuffix(":") || trimmed.hasSuffix(";") {
            return true
        }
        
        // Complete markdown elements are safe
        if trimmed.hasPrefix("#") || // Headers
           trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || // Lists
           trimmed.hasPrefix(">") || // Blockquotes
           trimmed.hasPrefix("```") { // Code blocks
            return true
        }
        
        // If the line is reasonably long and doesn't look like it's mid-sentence, it's probably safe
        if trimmed.count > 30 && !trimmed.hasSuffix(",") && !trimmed.hasSuffix("and") && !trimmed.hasSuffix("or") {
            return true
        }
        
        return false
    }
    
    private func isLineDefinitelyComplete(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Empty lines are complete
        if trimmed.isEmpty {
            return true
        }
        
        // Lines ending with clear punctuation
        if trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
            return true
        }
        
        // Complete markdown structures
        if trimmed.hasPrefix("#") || trimmed.hasPrefix("```") {
            return true
        }
        
        // Complete math expressions
        if isCompleteMathExpression(trimmed) {
            return true
        }
        
        return false
    }
    
    private func isIncompleteMarkdownStructure(_ line: String, nextLine: String?) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Check for incomplete code blocks
        if trimmed.hasPrefix("```") && !trimmed.hasSuffix("```") {
            return true
        }
        
        // Check for incomplete tables (if next line might be a table separator)
        if trimmed.contains("|") && nextLine?.contains("---") == true {
            return true
        }
        
        return false
    }
    
    private func containsIncompleteMath(_ text: String) -> Bool {
        // Count dollar signs to detect incomplete math expressions
        let dollarCount = text.components(separatedBy: "$").count - 1
        
        // Odd number of dollar signs means incomplete math
        if dollarCount % 2 != 0 {
            return true
        }
        
        // Check for incomplete display math
        let doubleDollarCount = text.components(separatedBy: "$$").count - 1
        if doubleDollarCount % 2 != 0 {
            return true
        }
        
        // Check for incomplete LaTeX commands
        if text.contains("\\") && !isCompleteLaTeXCommand(text) {
            return true
        }
        
        return false
    }
    
    private func isCompleteLaTeXCommand(_ text: String) -> Bool {
        // Simple check for common LaTeX commands that might be incomplete
        let incompletePatterns = ["\\frac{", "\\sqrt{", "\\sum_{", "\\int_{", "\\lim_{"]
        
        for pattern in incompletePatterns {
            if text.contains(pattern) {
                // Check if the command is properly closed
                let openBraces = text.components(separatedBy: "{").count - 1
                let closeBraces = text.components(separatedBy: "}").count - 1
                if openBraces > closeBraces {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func isCompleteMathExpression(_ line: String) -> Bool {
        // Check if line contains complete math expressions
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Display math: $$...$$
        if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count > 4 {
            return true
        }
        
        // Inline math: $...$
        if trimmed.hasPrefix("$") && trimmed.hasSuffix("$") && trimmed.count > 2 && !trimmed.hasPrefix("$$") {
            return true
        }
        
        // LaTeX environments: \begin{...} ... \end{...}
        if trimmed.hasPrefix("\\begin{") && trimmed.contains("\\end{") {
            return true
        }
        
        // Check if the line contains only complete math expressions
        let dollarCount = trimmed.components(separatedBy: "$").count - 1
        if dollarCount >= 2 && dollarCount % 2 == 0 {
            // Even number of dollar signs suggests complete math expressions
            return true
        }
        
        return false
    }
}
