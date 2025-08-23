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
    let cursorVisible: Bool
    @State private var showButtons = false
    @Environment(\.colorScheme) var colorScheme
    
    init(message: ChatMessage, onRegenerate: (() -> Void)? = nil, onVersionChange: ((Int) -> Void)? = nil, fontSize: Double = 14.0, showCursor: Bool = false, cursorVisible: Bool = true) {
        self.message = message
        self.onRegenerate = onRegenerate
        self.onVersionChange = onVersionChange
        self.fontSize = fontSize
        self.showCursor = showCursor
        self.cursorVisible = cursorVisible
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
                                    textColor: textColor,
                                    cursorVisible: cursorVisible
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
                                    .allowsHitTesting(false)
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
    let cursorVisible: Bool
    
    @State private var stableContent: String = ""
    @State private var streamingContent: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Rendered stable content (everything up to the last complete sentence/paragraph)
            if !stableContent.isEmpty {
                MarkdownMathRenderer(
                    content: stableContent,
                    fontSize: fontSize,
                    isStreaming: false
                )
                .allowsHitTesting(false)
            }
            
            // Raw streaming content (the incomplete part being typed)
            if !streamingContent.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Text(streamingContent)
                        .font(.system(size: fontSize))
                        .foregroundColor(textColor)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                    
                    // Cursor after streaming content
                    Rectangle()
                        .fill(textColor)
                        .frame(width: 2, height: fontSize)
                        .opacity(cursorVisible ? 1.0 : 0.0)
                        .allowsHitTesting(false)
                        .padding(.leading, 4)
                        .padding(.top, 2)
                }
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
        // Split content into stable (complete) and streaming (incomplete) parts
        let lines = fullContent.components(separatedBy: .newlines)
        
        // Find the last complete paragraph/sentence
        var stableLines: [String] = []
        var streamingLines: [String] = []
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Consider a line "complete" if it ends with punctuation or is followed by an empty line
            let isComplete = trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") || 
                            trimmed.hasSuffix(":") || trimmed.isEmpty ||
                            (index < lines.count - 1 && lines[index + 1].trimmingCharacters(in: .whitespaces).isEmpty)
            
            if isComplete && index < lines.count - 2 {
                // This line is complete and not one of the last two lines
                stableLines.append(line)
            } else {
                // This line and everything after is still streaming
                streamingLines = Array(lines[index...])
                break
            }
        }
        
        stableContent = stableLines.joined(separator: "\n")
        streamingContent = streamingLines.joined(separator: "\n")
        
        // If everything looks incomplete, show last few complete sentences as stable
        if stableContent.isEmpty && fullContent.count > 100 {
            let sentences = fullContent.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            if sentences.count > 2 {
                let stableSentences = sentences.dropLast(2)
                stableContent = stableSentences.joined(separator: ". ") + "."
                streamingContent = sentences.suffix(2).joined(separator: ". ")
            } else {
                streamingContent = fullContent
            }
        } else if stableContent.isEmpty {
            streamingContent = fullContent
        }
    }
}
