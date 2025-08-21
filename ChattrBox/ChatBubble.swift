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
    let fontSize: Double
    let showCursor: Bool
    let cursorVisible: Bool
    @State private var showButtons = false
    @Environment(\.colorScheme) var colorScheme
    
    init(message: ChatMessage, onRegenerate: (() -> Void)? = nil, fontSize: Double = 14.0, showCursor: Bool = false, cursorVisible: Bool = true) {
        self.message = message
        self.onRegenerate = onRegenerate
        self.fontSize = fontSize
        self.showCursor = showCursor
        self.cursorVisible = cursorVisible
    }
    
    private var backgroundColor: Color {
        if message.isUser {
            return Color.blue.opacity(0.6)
        } else {
            return colorScheme == .dark ? Color(hex: "171717") : Color(hex: "f4f4f4")
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
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    // Message content - simplified structure to eliminate spacing
                    if message.isUser {
                        // User messages - simple text, fit to content size
                        Text(message.content)
                            .font(.system(size: fontSize))
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing) // Right-align text within bubble
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
                        // AI messages - markdown and LaTeX rendering with MathJax
                        // Streamed data starts at TOP LEFT of box, no cursor taking up space
                        ZStack(alignment: .topLeading) {
                            MarkdownMathRenderer(content: message.content, fontSize: fontSize)
                                .padding(.horizontal, 16) // Match sent messages horizontal padding
                                .padding(.vertical, 8) // Match sent messages vertical padding
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(backgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(textColor)
                            
                            // Flashing loading cursor for AI responses
                            if showCursor {
                                Rectangle()
                                    .fill(textColor)
                                    .frame(width: 2, height: fontSize)
                                    .opacity(cursorVisible ? 1.0 : 0.0)
                                    .allowsHitTesting(false)
                                    .padding(.horizontal, 16) // Match AI response padding
                                    .padding(.top, 8) // Match AI response padding and position lower
                            }
                        }
                    }
                    
                    // Action buttons - single pill bubble containing both buttons
                    if showButtons {
                        HStack(spacing: 1) {
                                                        // Regenerate button (only for AI messages)
                            if !message.isUser && onRegenerate != nil {
                                Button(action: { onRegenerate?() }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .gray.opacity(0.8))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .help("Regenerate response")
                            }
                            
                            // Separator line between buttons
                            if !message.isUser && onRegenerate != nil {
                                Rectangle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                                    .frame(width: 0.5, height: 16)
                            }
                            
                            // Copy button
                            Button(action: copyMessage) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .gray.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                            }
                                .buttonStyle(.plain)
                                .help("Copy message")
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
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: message.id)
    }
    
    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)
    }
    

    

    

}





// Custom selectable text view for better text selection
struct SelectableText: NSViewRepresentable {
    let content: String
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize.zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.white
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.string = content
    }
}
