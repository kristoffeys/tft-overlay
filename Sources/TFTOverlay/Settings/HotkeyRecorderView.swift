import AppKit
import OverlayKit
import SwiftUI

/// One row in the General tab's hotkey list: shows the current binding and
/// lets the user record a replacement, with live conflict detection against
/// `HotkeyManager` (#4).
struct HotkeyRecorderRow: View {
    let action: AppHotkeyAction
    @ObservedObject var store: SettingsStore
    let hotkeyManager: HotkeyManager
    let onRebind: (AppHotkeyAction, Hotkey) -> Void

    @State private var isRecording = false
    @State private var conflictMessage: String?

    private var currentHotkey: Hotkey {
        store.settings.general.hotkeys[action.rawValue] ?? action.defaultHotkey
    }

    var body: some View {
        HStack {
            Text(action.displayName)
            Spacer()
            if let conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            RecorderButton(
                isRecording: $isRecording,
                label: isRecording ? "Press keys…" : HotkeyFormatting.displayString(for: currentHotkey)
            ) { keyCode, modifierFlags in
                attemptRebind(keyCode: keyCode, modifierFlags: modifierFlags)
            }
            .frame(width: 110)
        }
    }

    private func attemptRebind(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        let candidate = Hotkey(keyCode: keyCode, modifierFlags: modifierFlags)
        if let conflictingID = hotkeyManager.conflictingAction(for: candidate, excluding: action.action) {
            let label = AppHotkeyAction(rawValue: conflictingID.id)?.displayName ?? conflictingID.id
            conflictMessage = "Already used by \(label)"
            return
        }
        conflictMessage = nil
        onRebind(action, candidate)
    }
}

/// Button that, once clicked, becomes first responder and captures the next
/// key combination that includes at least one modifier — so a bare letter
/// meant for some other control in the window can never be mistaken for a
/// rebind.
private struct RecorderButton: NSViewRepresentable {
    @Binding var isRecording: Bool
    let label: String
    let onCapture: (UInt16, NSEvent.ModifierFlags) -> Void

    func makeNSView(context _: Context) -> RecorderButtonView {
        let view = RecorderButtonView()
        view.onCapture = { keyCode, flags in
            onCapture(keyCode, flags)
            isRecording = false
        }
        view.onStartRecording = { isRecording = true }
        return view
    }

    func updateNSView(_ nsView: RecorderButtonView, context _: Context) {
        nsView.title = label
        nsView.isRecording = isRecording
    }
}

private final class RecorderButtonView: NSButton {
    var onCapture: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var onStartRecording: (() -> Void)?
    var isRecording = false

    override var acceptsFirstResponder: Bool {
        true
    }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(startRecording)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func startRecording() {
        onStartRecording?()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        let relevantModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !relevantModifiers.isEmpty else { return }
        onCapture?(event.keyCode, relevantModifiers)
    }
}
