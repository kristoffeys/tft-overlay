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
    @StateObject private var pinnedStore = PinnedCompsStore(defaults: UserDefaults(suiteName: "TFTUIDemo") ?? .standard)

    enum Tab: String, CaseIterable, Identifiable {
        case list = "Comps"
        case detail = "Detail"
        case items = "Items"
        case compact = "Compact"
        case reference = "Reference"
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

            PinnedCompsRailView(comps: comps, store: pinnedStore) { comp in
                selectedComp = comp
                tab = .detail
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            Group {
                switch tab {
                case .list:
                    CompsListView(comps: comps, pinnedStore: pinnedStore) { comp in
                        selectedComp = comp
                        tab = .detail
                    }
                case .detail:
                    if let comp = selectedComp ?? comps.first {
                        CompDetailView(comp: comp, pinnedStore: pinnedStore)
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
                case .reference:
                    UnitTraitReferenceView(comps: comps) { comp in
                        selectedComp = comp
                        tab = .detail
                    }
                }
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 640, idealHeight: 780)
        .background(TFTTheme.background)
    }
}
