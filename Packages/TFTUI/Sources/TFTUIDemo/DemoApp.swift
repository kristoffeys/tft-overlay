import SwiftUI
import TFTUI

/// Lets the comps and item-sheet panels be seen and exercised without the
/// overlay window existing. Run with `swift run TFTUIDemo` from
/// `Packages/TFTUI`.
@main
struct TFTUIDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoRootView()
        }
    }
}

struct DemoRootView: View {
    @State private var comps: [Comp] = (try? CompLoader.bundledFixtures()) ?? []
    @State private var selectedComp: Comp?
    @State private var tab: Tab = .list

    enum Tab: String, CaseIterable, Identifiable {
        case list = "Comps"
        case detail = "Detail"
        case items = "Items"
        case compact = "Compact"
        var id: String {
            rawValue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(10)

            Group {
                switch tab {
                case .list:
                    CompsListView(comps: comps) { comp in
                        selectedComp = comp
                        tab = .detail
                    }
                case .detail:
                    if let comp = selectedComp ?? comps.first {
                        CompDetailView(comp: comp)
                    } else {
                        Text("No comps loaded").foregroundStyle(.white)
                    }
                case .items:
                    ItemCheatSheetView(comps: comps)
                case .compact:
                    ScrollView {
                        CompactItemCheatSheetView()
                            .padding(40)
                    }
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 640, idealHeight: 780)
        .background(TFTTheme.background)
    }
}
