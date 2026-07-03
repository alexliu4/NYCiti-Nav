import SwiftUI

@main
struct NYCitiNavApp: App {
    // Initializing the data manager at the app level as requested
    @StateObject private var dataManager = StationDataManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
