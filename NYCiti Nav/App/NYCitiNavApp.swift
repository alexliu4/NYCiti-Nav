import SwiftUI

@main
struct NYCitiNavApp: App {
    // Using @State for the observable data manager
    @State private var dataManager = StationDataManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataManager)
        }
    }
}
