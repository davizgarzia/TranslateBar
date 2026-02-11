import AppKit
import SwiftUI

/// Floating HUD window that shows translation status
final class TranslationHUD {
    static let shared = TranslationHUD()

    private var window: NSWindow?
    private var hostingView: NSHostingView<HUDContentView>?

    private init() {}

    /// Shows the HUD with the given message
    func show(message: String = "Translating...") {
        DispatchQueue.main.async { [weak self] in
            self?.createAndShowWindow(message: message)
        }
    }

    /// Hides the HUD
    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.window?.animator().alphaValue = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.window?.orderOut(nil)
                self?.window = nil
            }
        }
    }

    /// Updates the message while HUD is showing
    func update(message: String) {
        DispatchQueue.main.async { [weak self] in
            if let hostingView = self?.hostingView {
                hostingView.rootView = HUDContentView(message: message)
            }
        }
    }

    private func createAndShowWindow(message: String) {
        // Close existing window if any
        window?.orderOut(nil)

        // Create the SwiftUI content
        let contentView = HUDContentView(message: message)
        hostingView = NSHostingView(rootView: contentView)

        // Let the view size itself to fit content
        let fittingSize = hostingView?.fittingSize ?? NSSize(width: 200, height: 80)
        hostingView?.frame = NSRect(origin: .zero, size: fittingSize)

        // Create the window
        let hudWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        hudWindow.contentView = hostingView
        hudWindow.isOpaque = false
        hudWindow.backgroundColor = .clear
        hudWindow.level = .floating
        hudWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
        hudWindow.isMovableByWindowBackground = false
        hudWindow.hasShadow = false

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - fittingSize.width / 2
            let y = screenFrame.midY - fittingSize.height / 2
            hudWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show with fade in
        hudWindow.alphaValue = 0
        hudWindow.orderFront(nil)
        hudWindow.animator().alphaValue = 1

        self.window = hudWindow
    }
}

/// SwiftUI view for HUD content
struct HUDContentView: View {
    let message: String
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            Image("TransLiteIcon")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 13)
                .foregroundColor(.white.opacity(0.7))
                .opacity(isPulsing ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear {
                    isPulsing = true
                }

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
    }
}
