import SwiftUI

@main
struct FlowMDApp: App {
    @StateObject private var store = ClinicalStore()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store) }
    }
}
