@testable import TFTData
import XCTest

final class TFTDataStoreTests: XCTestCase {
    func testChampionLookupByID() {
        let ahri = Champion(id: "TFT_Ahri", name: "Ahri", cost: 4, traitIDs: ["StarGuardian"])
        let store = TFTDataStore(champions: [ahri])

        XCTAssertEqual(store.champion(id: "TFT_Ahri")?.name, "Ahri")
        XCTAssertNil(store.champion(id: "TFT_Unknown"))
    }
}
